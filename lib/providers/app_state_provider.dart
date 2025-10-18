// dcpos_app/lib/providers/app_state_provider.dart

import 'package:flutter/material.dart';

enum AppSection { dashboard, pos, inventory, users, settings }

class AppStateProvider with ChangeNotifier {
  AppSection _currentSection = AppSection.pos;

  AppSection get currentSection => _currentSection;

  void setSection(AppSection section) {
    if (_currentSection != section) {
      _currentSection = section;
      notifyListeners();
    }
  }

  static Map<AppSection, Map<String, dynamic>> sectionData = {
    AppSection.dashboard: {'name': 'Dashboard', 'icon': Icons.dashboard},
    AppSection.pos: {'name': 'Punto de Venta', 'icon': Icons.point_of_sale},
    AppSection.inventory: {'name': 'Inventario', 'icon': Icons.inventory_2},
    AppSection.users: {'name': 'Usuarios', 'icon': Icons.people},
    AppSection.settings: {'name': 'Configuración', 'icon': Icons.settings},
  };
}
