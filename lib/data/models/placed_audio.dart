import 'dart:convert';

class PlacedAudio {
  final String path;
  int durationMs;
  DateTime createdAt;
  double dx;
  double dy;
  double width;
  double height;
  int pageIndex;

  PlacedAudio({
    required this.path,
    required this.durationMs,
    DateTime? createdAt,
    this.dx = 0,
    this.dy = 0,
    this.width = 220,
    this.height = 80,
    this.pageIndex = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  String get durationText {
    final seconds = durationMs ~/ 1000;
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'durationMs': durationMs,
        'createdAt': createdAt.toIso8601String(),
        'dx': dx,
        'dy': dy,
        'width': width,
        'height': height,
        'pageIndex': pageIndex,
      };

  factory PlacedAudio.fromJson(Map<String, dynamic> json) => PlacedAudio(
        path: json['path'] as String,
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        dx: (json['dx'] as num?)?.toDouble() ?? 0,
        dy: (json['dy'] as num?)?.toDouble() ?? 0,
        width: (json['width'] as num?)?.toDouble() ?? 220,
        height: (json['height'] as num?)?.toDouble() ?? 80,
        pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
      );

  static List<PlacedAudio> parseList(dynamic raw) {
    if (raw == null || raw is! String || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .map((e) => PlacedAudio.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
