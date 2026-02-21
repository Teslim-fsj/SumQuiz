import 'package:flutter/material.dart';

class NavigationProvider with ChangeNotifier {
  int _selectedIndex = 0;

  int get selectedIndex => _selectedIndex;

  void setIndex(int index) {
    // Ensure index is within bounds (0-3 for 4 tabs)
    if (index < 0 || index > 3) return;

    if (_selectedIndex != index) {
      _selectedIndex = index;
      notifyListeners();
    }
  }
}
