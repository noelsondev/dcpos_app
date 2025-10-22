// dcpos_app/lib/models/local/user_local.dart

import 'package:isar/isar.dart';
import 'package:dcpos_app/models/domain/user.dart';

part 'user_local.g.dart';

@collection
class UserLocal {
  // 💡 CORRECCIÓN: Usamos Isar.autoIncrement para el ID principal
  Id id = Isar.autoIncrement;

  // El ID externo de la API. Debe ser ÚNICO para evitar duplicados.
  @Index(unique: true)
  String? externalId;

  // Campos de sesión/autenticación
  String? jwtToken;
  String? passwordHash; // Para validación offline futura

  // Datos del perfil
  String? username;
  int? roleId;
  String? roleName;
  String? companyId;
  String? branchId;
  bool? isActive;

  UserLocal({
    this.externalId,
    this.username,
    this.jwtToken,
    this.passwordHash,
    this.roleId,
    this.roleName,
    this.companyId,
    this.branchId,
    this.isActive,
  });

  // Factory para mapear desde el dominio API al modelo local (sin Id y Token)
  factory UserLocal.fromApiDomain(UserInDB user) {
    return UserLocal(
      externalId: user.id,
      username: user.username,
      roleId: user.roleId,
      roleName: user.roleName,
      companyId: user.companyId,
      branchId: user.branchId,
      isActive: user.isActive,
      // NO incluir jwtToken ni passwordHash aquí, se gestionan en la sesión.
    );
  }

  // Método para mapear del modelo local al dominio API
  UserInDB toApiDomain() {
    return UserInDB(
      id: externalId!,
      username: username ?? '',
      roleId: roleId!,
      roleName: roleName!,
      companyId: companyId,
      branchId: branchId,
      isActive: isActive!,
    );
  }

  // Copiar para manipular el ID de sesión (ID=1)
  UserLocal copyWith({
    Id? id,
    String? jwtToken,
  }) {
    return UserLocal()
      ..id = id ?? this.id
      ..externalId = externalId
      ..username = username
      ..roleId = roleId
      ..roleName = roleName
      ..companyId = companyId
      ..branchId = branchId
      ..isActive = isActive
      ..passwordHash = passwordHash
      // El token es el que más cambia, puede venir actualizado
      ..jwtToken = jwtToken ?? this.jwtToken;
  }
}
