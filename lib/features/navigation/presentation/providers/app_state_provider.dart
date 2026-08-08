import 'package:flutter/material.dart';

enum AppView { dashboard, userManagement, registrationRequests, driverManagement, userRequests, driverTracking }

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
      case 2: return AppView.registrationRequests;
      case 3: return AppView.driverManagement;
      case 4: return AppView.userRequests;
      case 5: return AppView.driverTracking;
      default: return AppView.dashboard;
    }
  }
}
