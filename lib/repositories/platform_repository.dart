// /lib/repositories/platform_repository.dart (MODIFICADO)

import 'package:dcpos_app/services/api_service.dart';
import 'package:dcpos_app/data_sources/local_platform_data_source.dart';
import 'package:dcpos_app/models/domain/platform.dart';
import 'package:dcpos_app/models/local/platform_local.dart';
import 'package:dcpos_app/data_sources/api_client.dart'; // Para NetworkException

class PlatformRepository {
  final ApiService _apiService;
  final LocalPlatformDataSource _localDataSource;

  PlatformRepository(this._apiService, this._localDataSource);

  // ==========================================================
  // Sincronización (Lectura: Cache-First) - CORREGIDO
  // ==========================================================

  /// Obtiene y sincroniza todas las compañías.
  Future<List<CompanyInDB>> getCompanies() async {
    try {
      // 1. Obtener de la API
      final List<CompanyInDB> apiCompanies = await _apiService.fetchCompanies();

      // 2. Mapear a Local y GUARDAR en Isar (Sincronización)
      final List<CompanyLocal> localCompanies = apiCompanies
          .map((c) => CompanyLocal.fromApiDomain(c))
          .toList();

      await _localDataSource.saveCompanies(localCompanies);

      // 3. Devolver el modelo de dominio para el Provider
      return apiCompanies;
    } on Exception catch (e) {
      // 4. Si falla la red/API, cargamos desde Isar.
      //    Nota: Estamos capturando cualquier 'Exception', lo cual incluye DioException.
      print(
        "Error al acceder a la red/API: $e. Cargando datos desde Isar (Offline).",
      );

      final List<CompanyLocal> localCompanies = await _localDataSource
          .getAllCompanies();

      // 5. Mapeo inverso de Local (Isar) a Domain (para el Provider)
      return localCompanies
          .map(
            (c) => CompanyInDB(
              id: c.externalId,
              name: c.name,
              slug: c.slug,
              createdAt: c.createdAt,
            ),
          )
          .toList();
    }
  }

  // ... (getBranches no requiere cambios ya que la lógica es similar a getCompanies) ...
  Future<List<BranchInDB>> getBranches(String companyId) async {
    try {
      final List<BranchInDB> apiBranches = await _apiService.fetchBranches(
        companyId,
      );

      final List<BranchLocal> localBranches = apiBranches
          .map((b) => BranchLocal.fromApiDomain(b))
          .toList();

      await _localDataSource.saveBranches(localBranches);

      return apiBranches;
    } on Exception catch (e) {
      print(
        "Error al acceder a la red/API: $e. Cargando sucursales desde Isar (Offline).",
      );

      final List<BranchLocal> localBranches = await _localDataSource
          .getBranchesByCompanyId(companyId);

      return localBranches
          .map(
            (b) => BranchInDB(
              id: b.externalId,
              companyId: b.companyId,
              name: b.name,
              address: b.address,
            ),
          )
          .toList();
    }
  }

  // ==========================================================
  // Mutación (Creación: Solo API) - CORREGIDO
  // ==========================================================

  /// Crea una nueva compañía y la guarda inmediatamente en la base de datos local (Isar).
  Future<CompanyInDB> createCompany(CompanyCreate companyCreate) async {
    // 1. Llama a la API (el ApiService maneja la excepción si falla)
    final CompanyInDB newCompany = await _apiService.createCompany(
      companyCreate,
    );

    // 2. CONVERSIÓN Y GUARDADO LOCAL (NUEVA LÍNEA)
    final CompanyLocal localCompany = CompanyLocal.fromApiDomain(newCompany);
    await _localDataSource.saveCompanies([localCompany]);

    // 3. Devuelve el modelo de dominio
    return newCompany;
  }

  /// Crea una nueva sucursal y la guarda inmediatamente en Isar.
  Future<BranchInDB> createBranch(
    String companyId,
    BranchCreate branchCreate,
  ) async {
    // 1. Llama a la API
    final BranchInDB newBranch = await _apiService.createBranch(
      companyId,
      branchCreate,
    );

    // 2. CONVERSIÓN Y GUARDADO LOCAL (NUEVA LÍNEA)
    final BranchLocal localBranch = BranchLocal.fromApiDomain(newBranch);
    await _localDataSource.saveBranches([localBranch]);

    // 3. Devuelve el modelo de dominio
    return newBranch;
  }
}
