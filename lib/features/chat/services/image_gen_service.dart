import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/ai_provider.dart';
import '../models/image_gen_result.dart';
import 'ai_config_store.dart';
import 'attachment_store.dart';
import 'image_gen_codec.dart';

/// 生图能力的门面。
///
/// 只负责「拿到一张图并落盘」这一件事 —— 提示词从哪来（用户手输 / 模型自己判断）
/// 由调用方决定。
///
/// 走的是 OpenAI 兼容的 `POST {baseUrl}/images/generations`，
/// 返回 `url` 或 `b64_json` 都能接（见 [parseImageResponse]）。
class ImageGenService {
  /// 生图接口普遍很慢（10~60 秒），超时给宽一点
  static const Duration requestTimeout = Duration(seconds: 180);

  /// 下载生成结果（厂商返回 url 时）的超时
  static const Duration downloadTimeout = Duration(seconds: 60);

  /// 用户中途取消时抛出的提示语。调用方一般会直接丢弃结果，不再展示。
  static const String abortedMessage = '已取消生成';

  http.Client? _activeClient;
  bool _aborted = false;

  bool get isGenerating => _activeClient != null;

  /// 中断正在进行的生图请求。
  ///
  /// 关掉 client 会让在途请求立刻抛异常，调用方（ChatProvider）随后丢掉结果。
  /// 生图动辄几十秒，没有这个的话「停止」按钮要等到底才有反应。
  void abort() {
    _aborted = true;
    _activeClient?.close();
    _activeClient = null;
  }

  /// 生图配置是否就绪。就绪返回 null，否则返回可以直接甩给用户看的原因。
  ///
  /// 入口按钮在**弹出输入框之前**先问一句，免得用户辛苦写完描述才发现没配 API。
  Future<String?> checkReady() async {
    final config = await AiConfigStore.load();
    return _blockReason(config.activeProvider(AiCapability.image));
  }

  /// 生成一张图并落盘到应用私有目录。
  ///
  /// [referenceImagePath] 给定时走**图生图**（「照着我这张照片画成…」），
  /// 否则是纯文生图。
  Future<ImageGenResult> generateAndStore(
    String prompt, {
    String? referenceImagePath,
  }) async {
    final text = prompt.trim();
    if (text.isEmpty) throw Exception('请先描述你想要的画面');

    final config = await AiConfigStore.load();
    final provider = config.activeProvider(AiCapability.image);
    final blocked = _blockReason(provider);
    if (blocked != null) throw Exception(blocked);

    final reference = (referenceImagePath ?? '').trim();

    _aborted = false;
    final client = http.Client();
    _activeClient = client;
    try {
      final payload = reference.isEmpty
          ? await _requestImage(
              client: client,
              baseUrl: provider!.baseUrl,
              apiKey: provider.apiKey,
              model: config.activeModel(AiCapability.image) ?? '',
              prompt: text,
            )
          : await _requestEdit(
              client: client,
              baseUrl: provider!.baseUrl,
              apiKey: provider.apiKey,
              model: config.activeModel(AiCapability.image) ?? '',
              prompt: text,
              imagePath: reference,
            );

      final bytes = await _resolveBytes(client, payload);
      if (bytes == null || bytes.isEmpty) {
        throw Exception('生图接口没有返回图片数据');
      }

      final ext = guessImageExtension(url: payload.url);
      final attachment = await AttachmentStore.saveBytes(
        bytes,
        name: 'AI生图$ext',
        mimeType: imageMimeOf(ext),
      );

      return ImageGenResult(
        path: attachment.path,
        prompt: text,
        revisedPrompt: payload.revisedPrompt,
      );
    } finally {
      // 被 abort() 关过的 client 不重复关（abort 里已置空 _activeClient）
      if (identical(_activeClient, client)) {
        _activeClient = null;
        client.close();
      }
    }
  }

  /// 缺厂商 / 缺 Key / 缺地址 —— 三种「还没配好」的文案只写这一处
  static String? _blockReason(AiProvider? provider) {
    if (provider == null) {
      return '还没有配置生图厂商，请到「AI 助手设置 → 生图」里添加';
    }
    if (!provider.hasApiKey) {
      return '生图厂商「${provider.name}」还没填 API Key';
    }
    if (provider.baseUrl.isEmpty) {
      return '生图厂商「${provider.name}」未配置 API 地址';
    }
    return null;
  }

  // ─────────────────────────────────────────────
  // 内部
  // ─────────────────────────────────────────────

  Future<ImagePayload> _requestImage({
    required http.Client client,
    required String baseUrl,
    required String apiKey,
    required String model,
    required String prompt,
    String? imageBase64,
  }) async {
    final url = '${_trimSlash(baseUrl)}/images/generations';

    final http.Response response;
    try {
      response = await client
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(
              buildImageRequestBody(
                model: model,
                prompt: prompt,
                imageBase64: imageBase64,
              ),
            ),
          )
          .timeout(requestTimeout);
    } catch (e) {
      throw Exception(_aborted ? abortedMessage : '生图请求失败：$e');
    }

    if (response.statusCode != 200) {
      throw Exception(
        '生图失败 (${response.statusCode})：${_shortBody(response.body)}',
      );
    }

    return _decodePayload(response);
  }

  /// 图生图：优先走 `/images/edits`（OpenAI 兼容协议的标准端点，multipart）。
  ///
  /// 厂商没实现这个端点、或这个模型在它上面不可用时
  /// （见 [looksLikeMissingEditEndpoint]），退回 `/images/generations` 并把
  /// 参考图以 base64 塞进 JSON —— 国内不少厂商就是这么接图生图的。
  ///
  /// 两条路都失败时，**报错里必须同时带上两次的原文** ——
  /// 只显示兜底那条的报错会让人误以为是「图生图本身不行」，
  /// 而真相往往是「edits 端点没有上游通道，兜底那条又是另一个原因」。
  Future<ImagePayload> _requestEdit({
    required http.Client client,
    required String baseUrl,
    required String apiKey,
    required String model,
    required String prompt,
    required String imagePath,
  }) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('参考图不存在：$imagePath');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw Exception('参考图是空文件');

    final ext = p.extension(imagePath);
    final safeExt = ext.isEmpty ? '.png' : ext;
    final payload = buildImageEditMultipart(
      boundary: newMultipartBoundary(),
      prompt: prompt,
      model: model,
      fileName: 'reference$safeExt',
      mimeType: imageMimeOf(safeExt),
      imageBytes: bytes,
    );

    final http.Response response;
    try {
      response = await client
          .post(
            Uri.parse('${_trimSlash(baseUrl)}/images/edits'),
            headers: {
              'Content-Type': payload.contentType,
              'Authorization': 'Bearer $apiKey',
            },
            body: payload.body,
          )
          .timeout(requestTimeout);
    } catch (e) {
      throw Exception(_aborted ? abortedMessage : '图生图请求失败：$e');
    }

    if (response.statusCode == 200) return _decodePayload(response);

    if (looksLikeMissingEditEndpoint(response.statusCode)) {
      final firstTry =
          '${response.statusCode} ${_shortBody(response.body)}';
      try {
        return await _requestImage(
          client: client,
          baseUrl: baseUrl,
          apiKey: apiKey,
          model: model,
          prompt: prompt,
          imageBase64: base64Encode(bytes),
        );
      } catch (e) {
        // 用户主动取消：如实抛出，别包装成「图生图失败」
        if (e.toString().contains(abortedMessage)) rethrow;
        throw Exception(
          '图生图失败（两条路都没走通）。\n'
          '· /images/edits → $firstTry\n'
          '· /images/generations(带 image) → $e',
        );
      }
    }

    throw Exception(
      '图生图失败 (${response.statusCode})：${_shortBody(response.body)}',
    );
  }

  /// 把 200 响应解成 [ImagePayload]；结构不对就抛出可读的错误
  static ImagePayload _decodePayload(http.Response response) {
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw Exception('生图接口返回了无法解析的内容');
    }
    if (decoded is! Map) {
      throw Exception('生图接口返回格式不对');
    }

    final payload = parseImageResponse(Map<String, dynamic>.from(decoded));
    if (payload == null) {
      throw Exception('生图接口没有返回图片：${_shortBody(response.body)}');
    }
    return payload;
  }

  /// 把载荷变成真正的图片字节：b64 直接解，url 再下载一次。
  Future<List<int>?> _resolveBytes(
    http.Client client,
    ImagePayload payload,
  ) async {
    final b64 = payload.b64Json;
    if (b64 != null) {
      final decoded = decodeImageBase64(b64);
      if (decoded == null) throw Exception('生图返回的 base64 数据无法解码');
      return decoded;
    }

    final url = payload.url;
    if (url == null) return null;

    final http.Response response;
    try {
      response = await client.get(Uri.parse(url)).timeout(downloadTimeout);
    } catch (e) {
      throw Exception(_aborted ? abortedMessage : '下载生成的图片失败：$e');
    }
    if (response.statusCode != 200) {
      throw Exception('下载生成的图片失败 (${response.statusCode})');
    }
    return response.bodyBytes;
  }

  static String _trimSlash(String url) {
    var s = url.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// 错误信息里塞整段 HTML 会淹没有用信息，截断一下
  static String _shortBody(String body) {
    final oneLine = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (oneLine.length <= 300) return oneLine;
    return '${oneLine.substring(0, 300)}…';
  }
}
