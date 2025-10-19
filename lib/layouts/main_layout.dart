// dcpos_app/lib/layouts/main_layout.dart

import 'package:dcpos_app/main.dart';
import 'package:dcpos_app/pages/auth_checker.dart';
import 'package:dcpos_app/pages/companies_page.dart';
import 'package:dcpos_app/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // ¡Necesario para el estado!

// Importaciones de páginas de dashboard (Asegúrate de que existan)
import 'package:dcpos_app/pages/users_page.dart';
// import 'package:dcpos_app/pages/inventory_page.dart'; // Descomentar cuando la crees
// import 'package:dcpos_app/pages/dashboard_page.dart'; // Descomentar cuando la crees

import 'package:dcpos_app/utils/responsive_extension.dart';
import 'package:dcpos_app/providers/app_state_provider.dart';

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  // Lógica de Logout centralizada (se mantiene igual)
  void _handleLogout(BuildContext context) async {
    await apiService.logout();

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthChecker()),
        (Route<dynamic> route) => false,
      );
    }
  }

  // Nuevo método: Define qué Widget mostrar según la sección del AppStateProvider
  Widget _getSectionWidget(AppSection section) {
    switch (section) {
      case AppSection.users:
        return const UsersPage();
      // TODO: Añadir otras vistas a medida que se implementan
      // case AppSection.inventory:
      //   return const InventoryPage();
      case AppSection.pos:
        // Mantener la página de inicio o TPV como default para POS
        return const HomePage();
      case AppSection.companies: // ✅ NUEVA SECCIÓN
        return const CompaniesPage();
      case AppSection.dashboard:
      case AppSection.settings:
      default:
        return const HomePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usamos Consumer para escuchar el AppStateProvider y reconstruir cuando cambie la sección
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        // --- 1. Definicion de la Barra Inferior (Mobile) ---
        // Se mapean las secciones del AppSection a BottomNavigationBarItems
        final mobileNavItems = AppStateProvider.sectionData.entries
            .where(
              (entry) => entry.key != AppSection.dashboard,
            ) // El dashboard puede ser redundante en móvil
            .map((entry) {
              return BottomNavigationBarItem(
                icon: Icon(entry.value['icon'] as IconData),
                label: entry.value['name'] as String,
              );
            })
            .toList();

        final bottomNav = context.isMobile
            ? BottomNavigationBar(
                currentIndex: AppStateProvider.sectionData.keys
                    .toList()
                    .indexOf(appState.currentSection),
                onTap: (index) {
                  // Navegación en móvil basada en el índice
                  final selectedSection = AppStateProvider.sectionData.keys
                      .toList()[index];
                  appState.setSection(selectedSection);
                },
                selectedItemColor: Theme.of(context).colorScheme.primary,
                unselectedItemColor: Colors.grey,
                items: mobileNavItems,
              )
            : null;

        // --- 2. Definición del Drawer/Sidebar (Desktop) ---
        final isDesktop = !context.isMobile;
        final navDrawer = Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // Encabezado del Drawer
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: const Text(
                  'DCPOS Admin',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
              // Items de navegación
              ...AppStateProvider.sectionData.entries.map((entry) {
                final section = entry.key;
                final data = entry.value;
                return ListTile(
                  leading: Icon(data['icon'] as IconData),
                  title: Text(data['name'] as String),
                  selected: appState.currentSection == section,
                  onTap: () {
                    appState.setSection(section);
                    if (!isDesktop) {
                      Navigator.pop(context); // Cierra el drawer en móvil
                    }
                  },
                );
              }).toList(),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Cerrar Sesión'),
                onTap: () => _handleLogout(context),
              ),
            ],
          ),
        );

        // --- 3. Scaffold Principal ---
        return Scaffold(
          appBar: AppBar(
            title: Text(
              AppStateProvider.sectionData[appState.currentSection]!['name']
                  as String,
            ),
            // Solo mostrar el botón de logout en la AppBar si no hay Drawer (es decir, en móvil)
            actions: isDesktop
                ? null
                : [
                    IconButton(
                      icon: const Icon(Icons.logout),
                      tooltip: 'Cerrar Sesión',
                      onPressed: () => _handleLogout(context),
                    ),
                  ],
          ),

          // Mostrar el Drawer en desktop o en modo móvil si es un Drawer (no BottomNav)
          drawer: isDesktop ? null : navDrawer,

          // Contenido principal: divide entre Sidebar y Contenido si es Desktop
          body: isDesktop
              ? Row(
                  children: [
                    // El sidebar es el mismo Drawer, solo que permanentemente visible
                    SizedBox(width: 250, child: navDrawer),
                    Expanded(child: _getSectionWidget(appState.currentSection)),
                  ],
                )
              // Contenido principal para móvil
              : _getSectionWidget(appState.currentSection),

          // Barra inferior solo para móvil
          bottomNavigationBar: bottomNav,
        );
      },
    );
  }
}

// Nota: Asegúrate de que tu `HomePage` ya no tenga un Scaffold si se usa dentro del MainLayout.
