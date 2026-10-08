import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../data/models/diary_entry.dart';
import '../../../data/models/placed_audio.dart';
import '../../../shared/widgets/full_image_viewer.dart';
import '../../diary_write/services/audio_service.dart';
import '../../diary_write/services/image_service.dart';

/// 日记详情卡片（参考图1）
/// 全屏水彩背景下的大卡片，展示图片+手写文字+装饰
class DetailCard extends StatefulWidget {
  final DiaryEntry entry;

  const DetailCard({super.key, required this.entry});

  @override
  State<DetailCard> createState() => _DetailCardState();
}

class _DetailCardState extends State<DetailCard> {
  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final bodyColor = isDark ? AppColors.darkBodyText : AppColors.bodyText;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final cardBg = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppDimensions.carouselCardRadius),
        boxShadow: isDark ? AppColors.darkCardShadow : AppColors.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.carouselCardRadius),
        child: Stack(
          children: [
            // 水彩装饰边框
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(AppDimensions.carouselCardRadius),
                ),
              ),
            ),
            // 内容
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 现场信息条：写这篇时的日期时间 / 天气 / 地点。
                  // 采集依赖定位授权（见 WeatherService.captureForDiary），
                  // 所以「没开定位」自然表现为「整条不渲染」。
                  if (entry.weather.isNotEmpty || entry.location.isNotEmpty)
                    _buildMetaLine(entry, subtleColor, accentColor),

                  // 图片区域（展示所有图片）
                  if (entry.images.isNotEmpty)
                    _buildImageSection(context, entry.images, accentColor),

                  // 标题
                  if (entry.title.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      entry.title,
                      style: AppTextStyles.handwritingTitle.copyWith(
                        color: textColor,
                        fontSize: 22,
                      ),
                    ),
                  ],

                  // 心情+标签
                  if (entry.mood.isNotEmpty || entry.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (entry.mood.isNotEmpty) ...[
                          Text(entry.mood, style: const TextStyle(fontSize: 20)),
                          if (entry.moodLabel.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              entry.moodLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: accentColor.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ],
                        const Spacer(),
                        if (entry.tags.isNotEmpty)
                          ...entry.tags.take(3).map((tag) => Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '#$tag',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          )),
                      ],
                    ),
                  ],

                  // 分隔线
                  const SizedBox(height: 16),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.0),
                          accentColor.withValues(alpha: 0.2),
                          accentColor.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),

                  // 正文内容
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        entry.content,
                        style: AppTextStyles.body.copyWith(
                          color: bodyColor,
                          fontSize: 16,
                          height: 1.8,
                        ),
                      ),
                    ),
                  ),

                  // 录音区域
                  if (entry.audios.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildAudioSection(context, entry.audios, accentColor, subtleColor),
                  ],

                  // 底部信息
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '${entry.wordCount}字',
                        style: TextStyle(
                          fontSize: 12,
                          color: subtleColor.withValues(alpha: 0.5),
                        ),
                      ),
                      if (entry.images.length > 1) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.image_outlined,
                            size: 14, color: subtleColor.withValues(alpha: 0.5)),
                        const SizedBox(width: 4),
                        Text(
                          '${entry.images.length}张',
                          style: TextStyle(
                            fontSize: 12,
                            color: subtleColor.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                      if (entry.audios.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.mic_outlined,
                            size: 14, color: subtleColor.withValues(alpha: 0.5)),
                        const SizedBox(width: 4),
                        Text(
                          '${entry.audios.length}条',
                          style: TextStyle(
                            fontSize: 12,
                            color: subtleColor.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶部现场信息条：`10月8日 16:58 · 晴 23°C · 广东省深圳市福田区`
  ///
  /// 时间取 [DiaryEntry.createdAt]（= 写下这篇的那一刻），精确到分钟。
  /// 编辑旧日记不会改写它，所以它始终是「当时」的时间。
  Widget _buildMetaLine(
    DiaryEntry entry,
    Color subtleColor,
    Color accentColor,
  ) {
    final items = <String>[
      _formatMinute(entry.createdAt),
      if (entry.weather.isNotEmpty) entry.weather,
      if (entry.location.isNotEmpty) entry.location,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.place_outlined,
              size: 13,
              color: accentColor.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              items.join(' · '),
              style: TextStyle(
                fontSize: 11.5,
                color: subtleColor,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatMinute(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.month}月${d.day}日 $hh:$mm';
  }

  Widget _buildImageSection(BuildContext context, List images, Color accentColor) {
    // 路径列表一次算好，交给每张图 —— 点开大图时要能左右滑看**整组**，
    // 而不是只看点中的那一张。
    final paths = [for (final img in images) img.path as String];
    if (paths.length == 1) {
      return _buildSingleImage(context, paths[0], accentColor, paths, 0);
    }
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) =>
            _buildSingleImage(ctx, paths[i], accentColor, paths, i),
      ),
    );
  }

  Widget _buildSingleImage(
    BuildContext context,
    String path,
    Color accentColor,
    List<String> allPaths,
    int index,
  ) {
    return FutureBuilder<File>(
      future: ImageService.getImageFile(path),
      builder: (ctx, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            width: 280,
            height: 180,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: accentColor.withValues(alpha: 0.3),
              ),
            ),
          );
        }
        return GestureDetector(
          onTap: () => _showFullImage(context, allPaths, index),
          child: Container(
            width: 280,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                snapshot.data!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: accentColor.withValues(alpha: 0.06),
                  child: Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 40,
                      color: accentColor.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 全屏查看：传**整组**图片 + 当前下标，这样放大后能左右滑看其他张。
  Future<void> _showFullImage(
    BuildContext context,
    List<String> paths,
    int index,
  ) async {
    final files = <File>[];
    for (final path in paths) {
      files.add(await ImageService.getImageFile(path));
    }
    if (!context.mounted) return;
    await FullImageViewer.show(context, files, initialIndex: index);
  }

  Widget _buildAudioSection(BuildContext context, List<PlacedAudio> audios, Color accentColor, Color subtleColor) {
    return Column(
      children: audios.map<Widget>((audio) {
        return _AudioPlayerTile(audio: audio, accentColor: accentColor, subtleColor: subtleColor);
      }).toList(),
    );
  }
}

/// 录音播放组件
class _AudioPlayerTile extends StatefulWidget {
  final PlacedAudio audio;
  final Color accentColor;
  final Color subtleColor;

  const _AudioPlayerTile({
    required this.audio,
    required this.accentColor,
    required this.subtleColor,
  });

  @override
  State<_AudioPlayerTile> createState() => _AudioPlayerTileState();
}

class _AudioPlayerTileState extends State<_AudioPlayerTile> {
  AudioPlayer? _player;
  bool _isPlaying = false;
  bool _isInitializing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _positionSub;
  StreamSubscription? _completeSub;
  StreamSubscription? _durationSub;

  @override
  void initState() {
    super.initState();
    _duration = Duration(milliseconds: widget.audio.durationMs);
  }

  Future<void> _initPlayer() async {
    if (_player != null || _isInitializing) return;
    _isInitializing = true;

    try {
      _player = AudioPlayer();
      final file = await DiaryAudioService.getAudioFile(widget.audio.path);
      if (!await file.exists()) {
        _isInitializing = false;
        return;
      }

      await _player!.setSource(DeviceFileSource(file.path));

      _positionSub = _player!.onPositionChanged.listen((pos) {
        if (mounted) setState(() => _position = pos);
      });

      _completeSub = _player!.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
        }
      });

      _durationSub = _player!.onDurationChanged.listen((dur) {
        if (mounted) setState(() => _duration = dur);
      });
    } catch (_) {
      _player?.dispose();
      _player = null;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _togglePlay() async {
    await _initPlayer();
    if (_player == null || !mounted) return;

    try {
      if (_isPlaying) {
        await _player!.pause();
      } else {
        await _player!.resume();
      }
      setState(() => _isPlaying = !_isPlaying);
    } catch (_) {}
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _completeSub?.cancel();
    _durationSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.accentColor;
    final subtleColor = widget.subtleColor;
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // 播放/暂停按钮
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 进度条 + 时间
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: accentColor,
                        inactiveTrackColor: accentColor.withValues(alpha: 0.2),
                        thumbColor: accentColor,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        trackHeight: 3,
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                      ),
                      child: Slider(
                        value: progress.clamp(0.0, 1.0),
                        onChanged: (value) async {
                          await _initPlayer();
                          if (_player != null && _duration.inMilliseconds > 0) {
                            final pos = Duration(
                              milliseconds: (value * _duration.inMilliseconds).toInt(),
                            );
                            await _player!.seek(pos);
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_position),
                            style: TextStyle(fontSize: 11, color: subtleColor),
                          ),
                          Text(
                            _formatDuration(_duration),
                            style: TextStyle(fontSize: 11, color: subtleColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
