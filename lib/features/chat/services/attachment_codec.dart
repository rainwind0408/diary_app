/// 把附件编码成各家 API 通用的多模态 content part。
///
/// 只依赖 dart:io / dart:convert，不引入 Flutter，便于独立测试。
library;

import 'dart:convert';
import 'dart:io';

import '../models/chat_attachment.dart';

class AttachmentCodec {
  AttachmentCodec._();

  /// 读文件并转成 data URI。读失败返回 null —— 不让单个坏文件毁掉整次请求。
  static Future<String?> toDataUri(ChatAttachment attachment) async {
    try {
      final file = File(attachment.path);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      final mime = attachment.mimeType.isEmpty
          ? ChatAttachment.mimeOf(attachment.name)
          : attachment.mimeType;
      return 'data:$mime;base64,${base64Encode(bytes)}';
    } catch (_) {
      return null;
    }
  }

  /// OpenAI 风格的多模态 content parts。
  ///
  /// - 图片 → `image_url`
  /// - 视频 → `video_url`（OpenAI 兼容协议本身不含视频，能否识别取决于所选模型/网关）
  /// - 其他 → `file`（filename + file_data）
  ///
  /// 按需求不做能力探测、不做降级：编不出来就跳过该附件，其余照发。
  static Future<List<Map<String, dynamic>>> toOpenAiParts(
    String text,
    List<ChatAttachment> attachments,
  ) async {
    final parts = <Map<String, dynamic>>[];

    if (text.trim().isNotEmpty) {
      parts.add({'type': 'text', 'text': text});
    }

    for (final a in attachments) {
      final uri = await toDataUri(a);
      if (uri == null) continue;
      switch (a.kind) {
        case AttachmentKind.image:
          parts.add({
            'type': 'image_url',
            'image_url': {'url': uri},
          });
        case AttachmentKind.video:
          parts.add({
            'type': 'video_url',
            'video_url': {'url': uri},
          });
        case AttachmentKind.file:
          parts.add({
            'type': 'file',
            'file': {'filename': a.name, 'file_data': uri},
          });
      }
    }

    // 全部附件都编码失败时，至少保留文本，避免发出空 content
    if (parts.isEmpty) {
      parts.add({'type': 'text', 'text': text});
    }
    return parts;
  }
}
