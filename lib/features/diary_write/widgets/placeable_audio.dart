import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/placed_audio.dart';
import '../services/audio_service.dart';

class PlaceableAudio extends StatefulWidget {
  final PlacedAudio placedAudio;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<PlacedAudio> onUpdate;
  final VoidCallback onInteractionStart;
  final VoidCallback onInteractionEnd;

  const PlaceableAudio({
    super.key,
    required this.placedAudio,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
    required this.onUpdate,
    required this.onInteractionStart,
    required this.onInteractionEnd,
  });

  @override
  State<PlaceableAudio> createState() => _PlaceableAudioState();
}

class _PlaceableAudioState extends State<PlaceableAudio> {
  double _lastFocalPointDx = 0;
  double _lastFocalPointDy = 0;
  bool _isDragging = false;

  // Audio player state
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
    _duration = Duration(milliseconds: widget.placedAudio.durationMs);
  }

  Future<void> _initPlayer() async {
    if (_player != null || _isInitializing) return;
    _isInitializing = true;

    try {
      _player = AudioPlayer();
      final file =
          await DiaryAudioService.getAudioFile(widget.placedAudio.path);
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
    final audio = widget.placedAudio;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? AppColors.darkCardBackgroundAlt : AppColors.cardBackgroundAlt;
    final accentColor =
        isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final subtleColor =
        isDark ? AppColors.darkSubtleText : AppColors.subtleText;

    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Positioned(
      left: audio.dx,
      top: audio.dy,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Audio card body (draggable)
          Listener(
            onPointerDown: (event) {
              widget.onInteractionStart();
              _lastFocalPointDx = event.position.dx;
              _lastFocalPointDy = event.position.dy;
              _isDragging = true;
            },
            onPointerMove: (event) {
              if (!_isDragging) return;
              final dx = event.position.dx - _lastFocalPointDx;
              final dy = event.position.dy - _lastFocalPointDy;
              _lastFocalPointDx = event.position.dx;
              _lastFocalPointDy = event.position.dy;

              widget.onUpdate(PlacedAudio(
                path: audio.path,
                durationMs: audio.durationMs,
                createdAt: audio.createdAt,
                dx: audio.dx + dx,
                dy: audio.dy + dy,
                width: audio.width,
                height: audio.height,
                pageIndex: audio.pageIndex,
              ));
            },
            onPointerUp: (_) {
              _isDragging = false;
              widget.onInteractionEnd();
            },
            onPointerCancel: (_) {
              _isDragging = false;
              widget.onInteractionEnd();
            },
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                width: audio.width,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(2, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Play button
                    GestureDetector(
                      onTap: _togglePlay,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor,
                        ),
                        child: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Progress + time
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              minHeight: 3,
                              backgroundColor:
                                  accentColor.withValues(alpha: 0.15),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(accentColor),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Time + label
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(_position),
                                style:
                                    TextStyle(fontSize: 10, color: subtleColor),
                              ),
                              Text(
                                '录音 ${audio.durationText}',
                                style:
                                    TextStyle(fontSize: 10, color: subtleColor),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Selection border
          if (widget.isSelected)
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                width: audio.width,
                height: audio.height,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          // Delete button
          if (widget.isSelected)
            Positioned(
              right: -12,
              top: -12,
              child: GestureDetector(
                onTap: widget.onDelete,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.close, size: 18, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
