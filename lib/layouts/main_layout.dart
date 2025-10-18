// dcpos_app/lib/layouts/main_layout.dart

import 'package:dcpos_app/main.dart';
import 'package:dcpos_app/pages/auth_checker.dart';
import 'package:dcpos_app/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dcpos_app/utils/responsive_extension.dart';
import 'package:dcpos_app/providers/app_state_provider.dart';
// Importa las vistas de placeholder
import 'package:dcpos_app/pages/placeholders.dart';

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  Widget _getSectionWidget(AppSection section) {
    switch (section) {
      case AppSection.dashboard:
        return const DashboardPage();
      case AppSection.pos:
        return const PosPage();
      case AppSection.inventory:
        return const DashboardPage(); // Placeholder
      case AppSection.users:
        return const UsersPage();
      case AppSection.settings:
        return const DashboardPage(); // Placeholder
      default:
        return const PosPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);

    // Layout para Desktop/Tablet (Barra Lateral)
    if (!context.isMobile) {
      return Scaffold(
        appBar: AppBar(
          actions: [
            // Botón de Cerrar Sesión
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar Sesión',
              onPressed: () async {
                // 1. Llamar a la función de logout (borra Isar)
                await apiService.logout();
                ;

                // 2. Navegar a la pantalla de inicio o login.
                // Forzamos la navegación y la limpieza de la pila
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    // Usamos MaterialPageRoute para ir a la pantalla que verifica la autenticación.
                    MaterialPageRoute(
                      builder: (context) => const AuthChecker(),
                    ),
                    // El predicado (modalRoute) => false asegura que todas las rutas anteriores sean removidas.
                    (Route<dynamic> route) => false,
                  );
                }
              },
            ),
          ],
          title: Text(
            AppStateProvider.sectionData[appState.currentSection]!['name']!,
          ),
          elevation: 1,
        ),
        body: Row(
          children: [
            // Panel de Navegación Lateral (Fijo)
            _buildNavigationPanel(context, appState, isDrawer: false),

            // Contenido principal expandido
            Expanded(child: _getSectionWidget(appState.currentSection)),
          ],
        ),
      );
    }
    // Layout para Móviles (Barra Inferior)
    else {
      return Scaffold(
        appBar: AppBar(
          actions: [
            // Botón de Cerrar Sesión
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar Sesión',
              onPressed: () async {
                // 1. Llamar a la función de logout (borra Isar)
                await apiService.logout();
                ;

                // 2. Navegar a la pantalla de inicio o login.
                // Forzamos la navegación y la limpieza de la pila
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    // Usamos MaterialPageRoute para ir a la pantalla que verifica la autenticación.
                    MaterialPageRoute(
                      builder: (context) => const AuthChecker(),
                    ),
                    // El predicado (modalRoute) => false asegura que todas las rutas anteriores sean removidas.
                    (Route<dynamic> route) => false,
                  );
                }
              },
            ),
          ],
          title: Text(
            AppStateProvider.sectionData[appState.currentSection]!['name']!,
          ),
          centerTitle: true,
        ),
        body: _getSectionWidget(appState.currentSection),

        // Barra de Navegación Inferior
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: AppSection.values.indexOf(appState.currentSection),
          onTap: (index) {
            appState.setSection(AppSection.values[index]);
          },
          items: AppSection.values.map((section) {
            final data = AppStateProvider.sectionData[section]!;
            return BottomNavigationBarItem(
              icon: Icon(data['icon']),
              label: data['name'],
            );
          }).toList(),
        ),
      );
    }
  }

  // Widget de Navegación Lateral
  Widget _buildNavigationPanel(
    BuildContext context,
    AppStateProvider appState, {
    required bool isDrawer,
  }) {
    final navItems = AppSection.values.map((section) {
      final data = AppStateProvider.sectionData[section]!;
      final isSelected = appState.currentSection == section;
      return ListTile(
        leading: Icon(
          data['icon'],
          color: isSelected
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onBackground,
        ),
        title: Text(
          data['name']!,
          style: TextStyle(
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onBackground,
          ),
        ),
        tileColor: isSelected ? Theme.of(context).colorScheme.primary : null,
        onTap: () {
          appState.setSection(section);
          if (isDrawer) Navigator.pop(context);
        },
      );
    }).toList();

    return Container(
      width: 250,
      color: Theme.of(context).colorScheme.surface,
      child: Column(children: [const SizedBox(height: 20), ...navItems]),
    );
  }
}
