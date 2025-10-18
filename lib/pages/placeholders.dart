// dcpos_app/lib/pages/placeholders.dart (Crea este archivo para las vistas)

import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text("Dashboard Content"));
}

class PosPage extends StatelessWidget {
  const PosPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text("Punto de Venta (POS) Content"));
}

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text("Gestión de Usuarios Content"));
}
// Mueve o crea estos tres archivos en lib/pages/