import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models/diary_entry.dart';
import '../../../data/repositories/diary_repository.dart';

enum ViewMode { list, grid }

class DiaryListProvider extends ChangeNotifier {
  final DiaryRepository _repository = DiaryRepository();

  List<DiaryEntry> _entries = [];
  bool _isLoading = false;
  String? _error;
  bool _isSearching = false;
  String _searchKeyword = '';
  String? _selectedTag;
  ViewMode _viewMode = ViewMode.list;

  List<DiaryEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSearching => _isSearching;
  String get searchKeyword => _searchKeyword;
  String? get selectedTag => _selectedTag;
  ViewMode get viewMode => _viewMode;

  DiaryListProvider() {
    _loadViewMode();
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('view_mode');
    if (saved == 'grid') {
      _viewMode = ViewMode.grid;
      notifyListeners();
    }
  }

  void toggleViewMode() {
    _viewMode = _viewMode == ViewMode.list ? ViewMode.grid : ViewMode.list;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('view_mode', _viewMode == ViewMode.grid ? 'grid' : 'list');
    }).catchError((_) {});
  }

  Future<void> loadEntries(DateTime date) async {
    if (_isSearching) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _entries = await _repository.getEntriesByDate(date);
    } catch (e) {
      _error = e.toString();
      _entries = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> searchEntries(String keyword) async {
    _searchKeyword = keyword;
    if (keyword.trim().isEmpty) {
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _entries = await _repository.searchEntries(keyword.trim());
    } catch (e) {
      _error = e.toString();
      _entries = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearSearch() {
    _isSearching = false;
    _searchKeyword = '';
    notifyListeners();
  }

  Future<void> filterByTag(String? tag, {DateTime? date}) async {
    _selectedTag = tag;
    if (tag == null) {
      notifyListeners();
      return;
    }
    _isLoading = true;
    notifyListeners();
    try {
      if (date != null) {
        _entries = await _repository.getEntriesByDateAndTag(date, tag);
      } else {
        _entries = await _repository.getEntriesByTag(tag);
      }
    } catch (e) {
      _error = e.toString();
      _entries = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteEntry(int id) async {
    try {
      await _repository.deleteEntry(id);
      _entries.removeWhere((e) => e.id == id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> lockEntry(int id, String pinHash) async {
    try {
      await _repository.updateLockStatus(id, true, pinHash);
      final index = _entries.indexWhere((e) => e.id == id);
      if (index != -1) {
        _entries[index] = _entries[index].copyWith(isLocked: true, pinHash: pinHash);
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> unlockEntry(int id) async {
    try {
      await _repository.updateLockStatus(id, false, '');
      final index = _entries.indexWhere((e) => e.id == id);
      if (index != -1) {
        _entries[index] = _entries[index].copyWith(isLocked: false, pinHash: '');
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
