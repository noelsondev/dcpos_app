// dcpos_app/lib/home_page.dart
import 'package:dcpos_app/utils/responsive_extension.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Lógica para el AppBar (Condicional)
    final appBarTitle = context.isMobile
        ? 'DCAPOS Móvil'
        : 'DCAPOS POS/Desktop';

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        actions: [
          if (context.isMobile)
            IconButton(onPressed: () {}, icon: const Icon(Icons.menu)),
        ],
      ),

      // 2. Lógica del Body: Diseño condicional
      body: Center(child: context.isMobile ? Text("movile") : Text("Desktop")),

      // 3. Lógica del BottomNavigationBar (Solo en móvil)
      bottomNavigationBar: context.isMobile
          ? BottomNavigationBar(
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Inicio',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Perfil',
                ),
              ],
            )
          : null,
    );
  }
}
