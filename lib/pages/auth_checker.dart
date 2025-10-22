// dcpos_app/lib/pages/auth_checker.dart

import 'package:flutter/material.dart';
import 'package:dcpos_app/main.dart';
import 'package:dcpos_app/layouts/main_layout.dart';
import 'package:dcpos_app/pages/login_page.dart';

// ¡RUTA CORREGIDA!
import 'package:dcpos_app/models/local/user_local.dart';

class AuthChecker extends StatelessWidget {
  const AuthChecker({super.key});

  Future<bool> _isUserLoggedIn() async {
    final isar = await isarService.db;
    final user = await isar.userLocals.get(1);

    return user != null && user.jwtToken != null && user.jwtToken!.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isUserLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Si el usuario está logueado, vamos al MainLayout
        if (snapshot.data == true) {
          return const MainLayout();
        } else {
          // Si no está logueado, vamos al Login
          return const LoginPage();
        }
      },
    );
  }
}
