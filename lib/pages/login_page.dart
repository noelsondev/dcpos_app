// dcpos_app/lib/pages/login_page.dart

import 'package:flutter/material.dart';
// 🛑 IMPORTAR IsarService (asumiendo que tiene la instancia global)

import 'package:dcpos_app/main.dart'; // Para apiService y isarService globales
import 'package:dcpos_app/utils/responsive_extension.dart';
import 'package:dcpos_app/layouts/main_layout.dart';

// Asumimos que 'isarService' y 'apiService' son instancias globales.

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  // ------------------------------------------------------------------
  // Nuevo método para limpiar Isar
  // ------------------------------------------------------------------
  Future<void> _handleClearIsar() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 🛑 CAMBIO CRÍTICO: Llama a isarService.clearAllData()
      await isarService.clearAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Base de datos local de Isar eliminada.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Error al limpiar DB: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  // ------------------------------------------------------------------

  Future<void> _handleLogin() async {
    // ... (Método de login sin cambios)
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await apiService.login(
        username: _usernameController.text,
        password: _passwordController.text,
      );

      // Si el login es exitoso, navegamos al MainLayout
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainLayout()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double formWidth = context.isMobile ? context.screenWidth * 0.9 : 400.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Inicio de Sesión'), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: SizedBox(
            width: formWidth,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'DCAPOS - Iniciar Sesión',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 40),

                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Usuario',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Introduce tu usuario'
                        : null,
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Introduce tu contraseña'
                        : null,
                  ),
                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'INICIAR SESIÓN',
                              style: TextStyle(fontSize: 18),
                            ),
                    ),
                  ),

                  // --------------------------------------------------
                  // BOTÓN DE DEBUG PARA LIMPIAR ISAR (Se mantiene)
                  // --------------------------------------------------
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleClearIsar,
                    icon: const Icon(Icons.delete_forever, size: 18),
                    label: const Text('⚠️ Borrar DB Local (Debug)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                  // --------------------------------------------------
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
