import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecordData {
  final String path;
  final int durationMs;
  final DateTime createdAt;

  AudioRecordData({
    required this.path,
    required this.durationMs,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'durationMs': durationMs,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AudioRecordData.fromJson(Map<String, dynamic> json) => AudioRecordData(
        path: json['path'] as String,
        durationMs: json['durationMs'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  String get durationText {
    final seconds = durationMs ~/ 1000;
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

class DiaryAudioService {
  DiaryAudioService._();

  static final AudioRecorder _recorder = AudioRecorder();
  static DateTime? _recordStartTime;

  static Future<String> get _audioDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/diary_audio');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  static Future<bool> hasPermission() async {
    return _recorder.hasPermission();
  }

  static Future<void> startRecording() async {
    final dir = await _audioDir;
    final path = '$dir/${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    _recordStartTime = DateTime.now();
  }

  static Future<AudioRecordData?> stopRecording() async {
    final path = await _recorder.stop();
    if (path == null) return null;

    final duration = _recordStartTime != null
        ? DateTime.now().difference(_recordStartTime!).inMilliseconds
        : 0;
    _recordStartTime = null;

    final appDir = await getApplicationDocumentsDirectory();
    final relativePath = path.replaceFirst('${appDir.path}/', '');

    return AudioRecordData(
      path: relativePath,
      durationMs: duration,
      createdAt: DateTime.now(),
    );
  }

  static Future<void> cancelRecording() async {
    await _recorder.stop();
    _recordStartTime = null;
  }

  static Future<bool> isRecording() async {
    return _recorder.isRecording();
  }

  static Future<File> getAudioFile(String relativePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    return File('${appDir.path}/$relativePath');
  }

  static Future<void> deleteAudio(String relativePath) async {
    final file = await getAudioFile(relativePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static List<AudioRecordData> parseAudios(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => AudioRecordData.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static String encodeAudios(List<AudioRecordData> audios) {
    return jsonEncode(audios.map((a) => a.toJson()).toList());
  }
}
