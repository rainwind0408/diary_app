import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/events/diary_change_bus.dart';
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
    // AI 在别的页面把日记改了 / 删了，这里要跟着刷新。
    // 订阅放在 Provider 而不是页面里：AI 可以在任何入口写日记
    //（聊天页、悬浮球语音直通），页面级订阅一定会漏。
    _unsubscribe = DiaryChangeBus.subscribe(_reload);
  }

  /// 记住最近一次加载的日期，供外部改动后原地刷新
  DateTime? _lastDate;
  void Function()? _unsubscribe;

  void _reload() {
    if (_isSearching && _searchKeyword.trim().isNotEmpty) {
      searchEntries(_searchKeyword);
      return;
    }
    final date = _lastDate;
    if (date != null) loadEntries(date);
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    _unsubscribe = null;
    super.dispose();
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
    _lastDate = date;
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
