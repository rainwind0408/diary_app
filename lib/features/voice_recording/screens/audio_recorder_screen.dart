import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../diary_write/services/audio_service.dart';

class AudioRecorderScreen extends StatefulWidget {
  const AudioRecorderScreen({super.key});

  static Future<AudioRecordData?> show(BuildContext context) {
    return Navigator.push<AudioRecordData>(
      context,
      MaterialPageRoute(
        builder: (_) => const AudioRecorderScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<AudioRecorderScreen> createState() => _AudioRecorderScreenState();
}

class _AudioRecorderScreenState extends State<AudioRecorderScreen>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  int _elapsedMs = 0;
  Timer? _timer;
  late AnimationController _pulseController;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _startRecording();
  }

  Future<void> _startRecording() async {
    final hasPermission = await DiaryAudioService.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要麦克风权限才能录音')),
        );
        Navigator.pop(context);
      }
      return;
    }

    try {
      await DiaryAudioService.startRecording();
      setState(() => _isRecording = true);

      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (mounted) setState(() => _elapsedMs += 100);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('录音启动失败')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final record = await DiaryAudioService.stopRecording();
    if (mounted) {
      Navigator.pop(context, record);
    }
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    await DiaryAudioService.cancelRecording();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  String _formatTime(int ms) {
    final seconds = ms ~/ 1000;
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkPageBackground : AppColors.pageBackground;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: _cancelRecording,
          icon: Icon(Icons.close, color: textColor),
        ),
        title: Text('录音', style: AppTextStyles.heading.copyWith(color: textColor)),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing red dot + timer
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 12 + _pulseController.value * 4,
                      height: 12 + _pulseController.value * 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.deleteRed.withValues(
                          alpha: 0.7 + _pulseController.value * 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatTime(_elapsedMs),
                      style: TextStyle(
                        fontSize: 48,
                        fontFamily: 'MaShanZheng',
                        color: textColor,
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 40),

            // Waveform visualization
            SizedBox(
              height: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(30, (i) {
                  final level = _isRecording ? 0.3 + _random.nextDouble() * 0.7 : 0.1;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    height: 8 + level * 60,
                    decoration: BoxDecoration(
                      color: AppColors.deleteRed.withValues(alpha: 0.4 + level * 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 60),

            // Stop button
            GestureDetector(
              onTap: _stopRecording,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.deleteRed,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deleteRed.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.stop, color: Colors.white, size: 32),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '点击停止录音',
              style: AppTextStyles.label.copyWith(color: subtleColor),
            ),
          ],
        ),
      ),
    );
  }
}
