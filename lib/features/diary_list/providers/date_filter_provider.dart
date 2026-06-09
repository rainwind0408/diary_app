import 'package:flutter/foundation.dart';

class DateFilterProvider extends ChangeNotifier {
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();

  DateTime get selectedDate => _selectedDate;
  DateTime get currentMonth => _currentMonth;

  void previousDay() {
    _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month);
    notifyListeners();
  }

  void nextDay() {
    _selectedDate = _selectedDate.add(const Duration(days: 1));
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month);
    notifyListeners();
  }

  void setDate(DateTime date) {
    _selectedDate = date;
    _currentMonth = DateTime(date.year, date.month);
    notifyListeners();
  }

  void setToday() {
    _selectedDate = DateTime.now();
    _currentMonth = DateTime.now();
    notifyListeners();
  }

  void previousMonth() {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    notifyListeners();
  }

  void nextMonth() {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    notifyListeners();
  }

  void setMonth(DateTime month) {
    _currentMonth = DateTime(month.year, month.month);
    notifyListeners();
  }
}
