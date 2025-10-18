// dcpos_app/lib/isar_service.dart

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
// ¡RUTA CORREGIDA!
import 'package:dcpos_app/models/local/user_local.dart';

class IsarService {
  late Future<Isar> db;

  IsarService() {
    db = openDB();
  }

  Future<Isar> openDB() async {
    if (Isar.instanceNames.isEmpty) {
      final dir = await getApplicationSupportDirectory();
      return await Isar.open(
        // 'UserLocalSchema' ahora es accesible vía la importación corregida
        [UserLocalSchema],
        directory: dir.path,
        inspector: true,
      );
    }
    return Future.value(Isar.getInstance());
  }
}
