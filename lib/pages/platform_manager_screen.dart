// dcpos_app/lib/screens/platform_manager_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dcpos_app/providers/app_state_provider.dart';
// Importa tus vistas (Crea los archivos si no existen aún)
import 'package:dcpos_app/pages/placeholders.dart';
import 'package:dcpos_app/pages/users_management_page.dart'; // NECESITA CREARSE
import 'package:dcpos_app/pages/companies_management_page.dart'; // NECESITA CREARSE

class PlatformManagerScreen extends StatelessWidget {
  const PlatformManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Usamos watch para reconstruir cuando cambia el estado (ej. currentSection)
    final appState = context.watch<AppStateProvider>();

    // Obtener las secciones visibles según el rol
    final availableSections = _getAvailableSections(
      appState.currentUserRoleName,
    );

    // Obtener el índice de la sección actual dentro de las secciones disponibles
    final currentSectionIndex = availableSections.indexOf(
      appState.currentSection,
    );

    return Scaffold(
      body: Row(
        children: <Widget>[
          // 1. Navigation Rail (Menú Lateral)
          NavigationRail(
            selectedIndex: currentSectionIndex,
            onDestinationSelected: (int index) {
              appState.setSection(availableSections[index]);
            },
            labelType: NavigationRailLabelType.all,
            destinations: availableSections.map((section) {
              final data = AppStateProvider.sectionData[section]!;
              return NavigationRailDestination(
                icon: Icon(data['icon']),
                label: Text(data['name']),
              );
            }).toList(),
            // Estilo
            minWidth: 56,
            minExtendedWidth: 150,
            extended:
                MediaQuery.of(context).size.width >
                800, // Extender en pantallas grandes
          ),

          // 2. Contenido Principal de la Sección
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _buildBody(appState.currentSection)),
        ],
      ),
    );
  }

  /// Retorna la lista de secciones disponibles según el rol del usuario.
  List<AppSection> _getAvailableSections(String roleName) {
    // Definimos las secciones que puede ver cada rol
    switch (roleName) {
      case 'global_admin':
        return [
          AppSection.dashboard,
          AppSection.companies, // Gestiona todas las compañías y sucursales
          AppSection.users, // Gestiona todos los usuarios
          AppSection.settings,
        ];
      case 'company_admin':
        return [
          AppSection.dashboard,
          AppSection.companies, // Solo ve su propia compañía
          AppSection.users, // Solo ve usuarios de su compañía
          AppSection.inventory,
          AppSection.pos,
          AppSection.settings,
        ];
      default: // Roles como 'cashier' o 'inventory_manager'
        return [
          AppSection.dashboard,
          AppSection.pos,
          AppSection.inventory,
          AppSection.settings,
        ];
    }
  }

  /// Retorna el Widget correspondiente a la sección actual.
  Widget _buildBody(AppSection section) {
    switch (section) {
      case AppSection.dashboard:
        return const DashboardPage();
      case AppSection.pos:
        return const PosPage();
      case AppSection.inventory:
        // return const InventoryPage(); // Vista a crear
        return const Center(child: Text("Gestión de Inventario"));
      case AppSection.users:
        return const UsersManagementPage(); // ⬅️ VISTA PRINCIPAL DE GESTIÓN DE USUARIOS
      case AppSection.companies:
        return const CompaniesManagementPage(); // ⬅️ VISTA PRINCIPAL DE GESTIÓN DE COMPAÑÍAS
      case AppSection.settings:
        return const Center(child: Text("Configuración de la App"));
      default:
        return const Center(child: Text("Sección No Implementada"));
    }
  }
}
