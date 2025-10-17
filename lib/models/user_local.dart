// dcpos_app/lib/models/user_local.dart

import 'package:isar/isar.dart';

part 'user_local.g.dart';

@collection
class UserLocal {
  // Isar utiliza la Id para la clave primaria.
  Id id = Isar.autoIncrement;

  // Usamos un índice único para asegurar que solo haya un usuario activo logueado
  @Index(unique: true)
  String? username;

  String? jwtToken;
  String? roleName; // e.g., 'company_admin', 'cashier'
  String? companyId; // Para referencia local

  bool isActive = true;
}
