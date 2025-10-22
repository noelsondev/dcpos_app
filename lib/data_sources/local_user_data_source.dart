// dcpos_app/lib/data_sources/local_user_data_source.dart

import 'package:dcpos_app/isar_service.dart';
import 'package:dcpos_app/models/local/user_local.dart';
import 'package:isar/isar.dart';

class LocalUserDataSource {
  final IsarService _isarService;

  LocalUserDataSource(this._isarService);

  // ==========================================================
  // LECTURA
  // ==========================================================

  Future<List<UserLocal>> getAllUsers() async {
    final isar = await _isarService.db;
    return await isar.userLocals.where().findAll();
  }

  Future<UserLocal?> getUserByUsername(String username) async {
    final isar = await _isarService.db;
    // Buscamos el usuario por su nombre de usuario (asumiendo que es único o buscamos el primero)
    return await isar.userLocals.filter().usernameEqualTo(username).findFirst();
  }

  // ==========================================================
  // MUTACIÓN
  // ==========================================================

  /// Guarda o actualiza una lista de usuarios usando el externalId como clave única.
  Future<void> saveUsers(List<UserLocal> users) async {
    final isar = await _isarService.db;

    await isar.writeTxn(() async {
      // 💡 CORRECCIÓN: Usamos putByExternalId para insertar/actualizar por externalId
      // Esto respeta el índice único y previene el error.
      await isar.userLocals.putAllByExternalId(users);
    });
  }

  /// Actualiza un usuario local de forma segura (sin tocar la sesión/hash).
  Future<void> updateUserSafe(UserLocal updatedUser) async {
    final isar = await _isarService.db;

    // 1. Encontrar el registro existente por externalId
    final existingUser = await isar.userLocals
        .filter()
        .externalIdEqualTo(updatedUser.externalId)
        .findFirst();

    if (existingUser == null) {
      // Si no existe, simplemente lo guardamos (o lanzamos un error)
      await saveUsers([updatedUser]);
      return;
    }

    // 2. Conservar los datos sensibles (ID local fijo, token, hash)
    final safeUser = updatedUser.copyWith(
      id: existingUser
          .id, // Conservar el ID local (puede ser 1 o autoIncrement)
      jwtToken: existingUser.jwtToken,
    );
    safeUser.passwordHash = existingUser.passwordHash;

    // 3. Guardar la versión segura (put usa el ID primario)
    await isar.writeTxn(() async {
      await isar.userLocals.put(safeUser);
    });
  }
}
