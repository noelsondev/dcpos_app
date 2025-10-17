// dcpos_app/lib/isar_service.dart

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'models/user_local.dart'; // Importar nuestro modelo

class IsarService {
  late Future<Isar> db;

  IsarService() {
    db = openDB();
  }

  Future<Isar> openDB() async {
    if (Isar.instanceNames.isEmpty) {
      final dir = await getApplicationSupportDirectory();
      return await Isar.open(
        // LISTA DE ESQUEMAS: Aquí incluimos todos los modelos Isar
        [UserLocalSchema],
        directory: dir.path,
        inspector: true,
      );
    }
    return Future.value(Isar.getInstance());
  }

  // Puedes añadir métodos aquí para interactuar con la DB:
  // Future<void> saveUser(UserLocal user) async {
  //   final isar = await db;
  //   await isar.writeTxn(() => isar.userLocals.put(user));
  // }
}
