// dcpos_app/lib/models/local/platform_local.dart (CORRECCIÓN FINAL)

import 'package:dcpos_app/models/domain/platform.dart';
import 'package:isar/isar.dart';
import 'package:dcpos_app/utils/hash_utils.dart'; // Asegúrate de que esta ruta sea correcta

// ==========================================================
// CompanyLocal (CORRECCIÓN FINAL)
// ==========================================================

part 'platform_local.g.dart';

@Collection()
class CompanyLocal {
  // 💡 CAMBIO CRÍTICO 1: Usamos fastHash(externalId) para el Isar ID.
  // Esto asegura que si el UUID es el mismo, el ID de Isar (int) es el mismo,
  // permitiendo que `putAll` haga un UPDATE en lugar de un INSERT.
  Id get id => fastHash(externalId);

  // 💡 CAMBIO CRÍTICO 2: ELIMINAMOS la anotación @Index(unique: true).
  // La unicidad se garantiza ahora por el 'id' de la colección.
  late String externalId; // Ya NO tiene @Index(unique: true)

  late String name;
  late String slug;
  late DateTime createdAt;

  static CompanyLocal fromApiDomain(CompanyInDB apiCompany) {
    return CompanyLocal()
      ..externalId = apiCompany.id
      ..name = apiCompany.name
      ..slug = apiCompany.slug
      ..createdAt = apiCompany.createdAt;
  }
}

// ==========================================================
// BranchLocal (CORRECCIÓN FINAL)
// ==========================================================

@Collection()
class BranchLocal {
  // 💡 CAMBIO CRÍTICO 1
  Id get id => fastHash(externalId);

  // 💡 CAMBIO CRÍTICO 2
  late String externalId; // Ya NO tiene @Index(unique: true)

  late String companyId;
  late String name;
  late String? address;

  static BranchLocal fromApiDomain(BranchInDB apiBranch) {
    return BranchLocal()
      ..externalId = apiBranch.id
      ..companyId = apiBranch.companyId
      ..name = apiBranch.name
      ..address = apiBranch.address;
  }
}
