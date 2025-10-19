// dcpos_app/lib/isar_service.dart (CORREGIDO sin kDebugMode)

import 'package:dcpos_app/models/local/platform_local.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dcpos_app/models/local/user_local.dart';
// Eliminamos la importación de flutter/foundation.dart

class IsarService {
  late Future<Isar> db;

  IsarService() {
    db = openDB();
  }

  Future<Isar> openDB() async {
    if (Isar.instanceNames.isEmpty) {
      final dir = await getApplicationSupportDirectory();
      return await Isar.open(
        [UserLocalSchema, CompanyLocalSchema, BranchLocalSchema],
        directory: dir.path,
        inspector: true,
      );
    }
    return Future.value(Isar.getInstance());
  }

  // -------------------------------------------------------------------
  // Z. Función de Mantenimiento de Datos (Limpiar Isar) - CORREGIDA
  // -------------------------------------------------------------------

  /// Elimina TODA la base de datos de Isar, incluyendo todas las colecciones.
  Future<void> clearAllData() async {
    // Si no usas kDebugMode, simplemente imprimimos el mensaje
    print(
      'DEBUG: Iniciando la eliminación de toda la base de datos local de Isar.',
    );

    // Obtener la instancia de la base de datos
    final isar = await db;

    // Ejecutar la operación de limpieza dentro de una transacción de escritura
    await isar.writeTxn(() async {
      await isar.clear();
    });

    print('DEBUG: Isar Database cleared successfully.');
  }
}
