import 'package:flutter/foundation.dart';
import '../models/sticker.dart';
import '../data/sticker_data.dart';

class StickerProvider extends ChangeNotifier {
  List<Sticker> _stickers = [];
  bool _loading = true;

  List<Sticker> get stickers => _stickers;
  bool get loading => _loading;

  List<String> get categories => StickerData.categories;

  void loadStickers() {
    _stickers = StickerData.presets;
    _loading = false;
    notifyListeners();
  }

  List<Sticker> getByCategory(String category) {
    return _stickers.where((s) => s.category == category).toList();
  }

  Sticker? findById(String id) {
    try {
      return _stickers.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}
