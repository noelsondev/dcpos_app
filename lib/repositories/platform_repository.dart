// /lib/repositories/platform_repository.dart

import 'package:dcpos_app/services/api_service.dart';
import 'package:dcpos_app/data_sources/local_platform_data_source.dart';
import 'package:dcpos_app/data_sources/local_user_data_source.dart'; // ⬅️ NUEVO: Data Source para Usuarios
import 'package:dcpos_app/models/domain/platform.dart';
import 'package:dcpos_app/models/domain/user.dart'; // ⬅️ NUEVO: Modelos de Dominio de Usuario
import 'package:dcpos_app/models/local/platform_local.dart';
import 'package:dcpos_app/models/local/user_local.dart'; // ⬅️ NUEVO: Modelo Local de Usuario
import 'package:dcpos_app/models/domain/company_update.dart'; // ⬅️ IMPORTAR
import 'package:dcpos_app/models/domain/branch_update.dart';

class PlatformRepository {
  final ApiService _apiService;
  final LocalPlatformDataSource
      _localDataSource; // Data Source para Compañías/Sucursales
  final LocalUserDataSource
      _localUserDataSource; // ⬅️ Data Source para Usuarios

  PlatformRepository(
    this._apiService,
    this._localDataSource,
    this._localUserDataSource, // ⬅️ INYECCIÓN
  );

  // ==========================================================
  // USUARIOS: Lectura (Cache-First) & Mutación (API-First, Write-Through)
  // ==========================================================

  /// Obtiene y sincroniza todos los usuarios.
  Future<List<UserInDB>> getUsers({String? companyId, String? branchId}) async {
    try {
      // 1. Obtener de la API (con filtros si aplican)
      final List<UserInDB> apiUsers = await _apiService.fetchUsers(
        companyId: companyId,
        branchId: branchId,
      );

      // 2. Mapear a Local y GUARDAR/ACTUALIZAR en Isar (Sincronización)
      final List<UserLocal> localUsers = apiUsers
          .map(
            (u) => UserLocal.fromApiDomain(u),
          ) // Asumimos este factory existe
          .toList();

      await _localUserDataSource.saveUsers(localUsers);

      // 3. Devolver el modelo de dominio
      return apiUsers;
    } on Exception catch (e) {
      // 4. Si falla la red/API, cargamos desde Isar (Offline).
      print(
        "Error al acceder a la red/API: $e. Cargando usuarios desde Isar (Offline).",
      );

      final List<UserLocal> localUsers =
          await _localUserDataSource.getAllUsers();

      // 5. Mapeo inverso de Local (Isar) a Domain (para el Provider)
      return localUsers
          .map((u) => u.toApiDomain()) // Asumimos este método existe
          .toList();
    }
  }

  /// Crea un nuevo usuario y lo guarda localmente.
  Future<UserInDB> createUser(UserCreate userCreate) async {
    final UserInDB newUser = await _apiService.createUser(userCreate);

    // Convertir a Local y guardar
    final UserLocal localUser = UserLocal.fromApiDomain(newUser);
    await _localUserDataSource.saveUsers([localUser]);

    return newUser;
  }

  /// Actualiza un usuario y lo guarda localmente de forma segura.
  Future<UserInDB> updateUser(String userId, UserUpdate userUpdate) async {
    final UserInDB updatedUser = await _apiService.updateUser(
      userId,
      userUpdate,
    );

    // Convertir a Local y actualizar de forma segura (sin sobreescribir token/hash)
    final UserLocal localUser = UserLocal.fromApiDomain(updatedUser);
    await _localUserDataSource.updateUserSafe(localUser);

    return updatedUser;
  }

  // ==========================================================
  // COMPANIES: Lectura (Cache-First) & Mutación (API-First, Write-Through)
  // ==========================================================

  /// Obtiene y sincroniza todas las compañías. (Cache-First)
  Future<List<CompanyInDB>> getCompanies() async {
    try {
      final List<CompanyInDB> apiCompanies = await _apiService.fetchCompanies();

      final List<CompanyLocal> localCompanies =
          apiCompanies.map((c) => CompanyLocal.fromApiDomain(c)).toList();

      await _localDataSource.saveCompanies(localCompanies);
      return apiCompanies;
    } on Exception catch (e) {
      print(
        "Error al acceder a la red/API: $e. Cargando datos desde Isar (Offline).",
      );

      final List<CompanyLocal> localCompanies =
          await _localDataSource.getAllCompanies();

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

  /// Crea una nueva compañía y la guarda inmediatamente en la base de datos local (API-First).
  Future<CompanyInDB> createCompany(CompanyCreate companyCreate) async {
    final CompanyInDB newCompany = await _apiService.createCompany(
      companyCreate,
    );

    final CompanyLocal localCompany = CompanyLocal.fromApiDomain(newCompany);
    await _localDataSource.saveCompanies([localCompany]);

    return newCompany;
  }

  /// Actualiza una compañía y la guarda en Isar. (API-First)
  Future<CompanyInDB> updateCompany(
    String companyId,
    CompanyUpdate companyUpdate,
  ) async {
    final CompanyInDB updatedCompany = await _apiService.updateCompany(
      companyId,
      companyUpdate,
    );

    final CompanyLocal localCompany = CompanyLocal.fromApiDomain(
      updatedCompany,
    );
    await _localDataSource.saveCompanies([localCompany]);

    return updatedCompany;
  }

  // ==========================================================
  // BRANCHES: Lectura (Cache-First) & Mutación (API-First, Write-Through)
  // ==========================================================

  /// Obtiene y sincroniza las sucursales por CompanyID. (Cache-First)
  Future<List<BranchInDB>> getBranches(String companyId) async {
    try {
      final List<BranchInDB> apiBranches = await _apiService.fetchBranches(
        companyId,
      );

      final List<BranchLocal> localBranches =
          apiBranches.map((b) => BranchLocal.fromApiDomain(b)).toList();

      await _localDataSource.saveBranches(localBranches);

      return apiBranches;
    } on Exception catch (e) {
      print(
        "Error al acceder a la red/API: $e. Cargando sucursales desde Isar (Offline).",
      );

      final List<BranchLocal> localBranches =
          await _localDataSource.getBranchesByCompanyId(companyId);

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

  /// Crea una nueva sucursal y la guarda inmediatamente en Isar. (API-First)
  Future<BranchInDB> createBranch(
    String companyId,
    BranchCreate branchCreate,
  ) async {
    final BranchInDB newBranch = await _apiService.createBranch(
      companyId,
      branchCreate,
    );

    final BranchLocal localBranch = BranchLocal.fromApiDomain(newBranch);
    await _localDataSource.saveBranches([localBranch]);

    return newBranch;
  }

  /// Actualiza una sucursal y la guarda en Isar. (API-First)
  Future<BranchInDB> updateBranch(
    String companyId,
    String branchId,
    BranchUpdate branchUpdate,
  ) async {
    final BranchInDB updatedBranch = await _apiService.updateBranch(
      companyId,
      branchId,
      branchUpdate,
    );

    final BranchLocal localBranch = BranchLocal.fromApiDomain(updatedBranch);
    await _localDataSource.saveBranches([localBranch]);

    return updatedBranch;
  }
}
