import 'package:flutter/material.dart';

enum AppView {
  dashboard,
  userManagement,
  driverManagement,
  userRequests,
  liveTracking,
}

class AppStateProvider with ChangeNotifier {
  int _selectedIndex = 0;

  int get selectedIndex => _selectedIndex;

  void setIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  AppView get currentView {
    switch (_selectedIndex) {
      case 0: return AppView.dashboard;
      case 1: return AppView.userManagement;
      case 2: return AppView.driverManagement;
      case 3: return AppView.userRequests;
      case 4: return AppView.liveTracking;
      default: return AppView.dashboard;
    }
  }
}
