import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../diary_write/services/audio_service.dart';

class InlineAudioPlayer extends StatefulWidget {
  final AudioRecordData audio;
  final VoidCallback? onDelete;

  const InlineAudioPlayer({
    super.key,
    required this.audio,
    this.onDelete,
  });

  @override
  State<InlineAudioPlayer> createState() => _InlineAudioPlayerState();
}

class _InlineAudioPlayerState extends State<InlineAudioPlayer> {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkCardBackgroundAlt : AppColors.cardBackgroundAlt;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;

    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return GestureDetector(
      onLongPress: widget.onDelete,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: goldColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.music_note, size: 20, color: goldColor),
                const SizedBox(width: 8),
                // Play button
                GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: goldColor,
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Progress bar + time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: goldColor,
                          inactiveTrackColor: goldColor.withValues(alpha: 0.2),
                          thumbColor: goldColor,
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
            const SizedBox(height: 4),
            // Recording date
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${widget.audio.createdAt.month}月${widget.audio.createdAt.day}日 ${widget.audio.createdAt.hour}:${widget.audio.createdAt.minute.toString().padLeft(2, '0')} 录音',
                style: AppTextStyles.cardDate.copyWith(color: subtleColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
