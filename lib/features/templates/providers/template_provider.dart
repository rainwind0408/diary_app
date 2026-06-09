import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/template.dart';
import '../data/template_defs.dart';

class TemplateProvider extends ChangeNotifier {
  List<DiaryTemplate> _templates = [];
  List<DiaryTemplate> _customTemplates = [];
  bool _loading = true;

  static const _customTemplatesKey = 'custom_templates';

  List<DiaryTemplate> get templates => _templates;
  bool get loading => _loading;

  List<DiaryTemplate> get presets => TemplateDefs.presets;
  List<DiaryTemplate> get customTemplates => _customTemplates;

  List<DiaryTemplate> getByCategory(TemplateCategory category) {
    if (category == TemplateCategory.custom) return _customTemplates;
    return presets.where((t) => t.category == category).toList();
  }

  List<DiaryTemplate> get allTemplates => [...presets, ..._customTemplates];

  Future<void> loadTemplates() async {
    _loading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_customTemplatesKey);
      if (json != null) {
        final list = jsonDecode(json) as List;
        _customTemplates = list
            .map((e) => DiaryTemplate.fromMap(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      _customTemplates = [];
    }

    _templates = [...presets, ..._customTemplates];
    _loading = false;
    notifyListeners();
  }

  Future<void> addCustomTemplate(DiaryTemplate template) async {
    final custom = template.copyWith(isCustom: true);
    _customTemplates.add(custom);
    _templates = [...presets, ..._customTemplates];
    notifyListeners();
    await _saveCustomTemplates();
  }

  Future<void> deleteCustomTemplate(String id) async {
    _customTemplates.removeWhere((t) => t.id == id);
    _templates = [...presets, ..._customTemplates];
    notifyListeners();
    await _saveCustomTemplates();
  }

  Future<void> _saveCustomTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_customTemplates.map((t) => t.toMap()).toList());
    await prefs.setString(_customTemplatesKey, json);
  }
}
