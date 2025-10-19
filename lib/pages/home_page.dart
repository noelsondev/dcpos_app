// dcpos_app/lib/pages/home_page.dart

import 'package:dcpos_app/utils/responsive_extension.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Aquí solo se define el cuerpo de la página.
    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Bienvenido al Sistema DCAPOS',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              context.isMobile
                  ? 'Estás usando la interfaz Móvil.'
                  : 'Estás usando la interfaz Desktop/POS.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 40),
            // Un botón de ejemplo para demostrar que estamos logueados
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Operación de prueba exitosa.')),
                );
              },
              child: const Text('Comenzar Operación'),
            ),
          ],
        ),
      ),
    );

    // Devolvemos un Scaffold simple con solo el contenido
    return Scaffold(
      // El AppBar y BottomNavigationBar se gestionan en MainLayout
      body: content,
    );
  }
}
