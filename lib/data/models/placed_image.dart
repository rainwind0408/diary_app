import 'dart:convert';

class PlacedImage {
  final String path;
  double dx;
  double dy;
  double width;
  double height;
  double rotation;
  double scale;
  int pageIndex;

  PlacedImage({
    required this.path,
    this.dx = 0,
    this.dy = 0,
    this.width = 200,
    this.height = 150,
    this.rotation = 0,
    this.scale = 1.0,
    this.pageIndex = 0,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'dx': dx,
        'dy': dy,
        'width': width,
        'height': height,
        'rotation': rotation,
        'scale': scale,
        'pageIndex': pageIndex,
      };

  factory PlacedImage.fromJson(Map<String, dynamic> json) => PlacedImage(
        path: json['path'] as String,
        dx: (json['dx'] as num).toDouble(),
        dy: (json['dy'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
        scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
        pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
      );

  static List<PlacedImage> parseList(dynamic raw) {
    if (raw == null) return [];
    final decoded = jsonDecode(raw as String);
    if (decoded is! List) return [];
    return decoded.map((item) {
      if (item is String) return PlacedImage(path: item);
      return PlacedImage.fromJson(item as Map<String, dynamic>);
    }).toList();
  }
}
