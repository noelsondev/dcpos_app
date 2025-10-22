// dcpos_app/lib/providers/app_state_provider.dart

import 'package:flutter/material.dart';
import 'package:dcpos_app/models/domain/user.dart';
import 'package:dcpos_app/models/domain/platform.dart';
import 'package:dcpos_app/repositories/platform_repository.dart';
import 'package:dcpos_app/models/domain/company_update.dart'; // ⬅️ IMPORTAR
import 'package:dcpos_app/models/domain/branch_update.dart';

// NUEVO ENUM
enum AppSection { dashboard, pos, inventory, users, companies, settings }

class AppStateProvider with ChangeNotifier {
  // -------------------------------------------------------------------
  // DEPENDENCIA INYECTADA
  // -------------------------------------------------------------------
  final PlatformRepository _platformRepository;

  AppStateProvider({required PlatformRepository platformRepository})
      : _platformRepository = platformRepository {
    // Inicializar la carga de la sección por defecto (o la que se necesite)
    if (_currentSection == AppSection.companies) {
      fetchCompanies();
    } else if (_currentSection == AppSection.users) {
      fetchUsers();
    }
  }

  // -------------------------------------------------------------------
  // ESTADO DE LA APLICACIÓN Y DATOS DEL USUARIO LOGUEADO
  // -------------------------------------------------------------------
  AppSection _currentSection = AppSection.companies;

  // ⚠️ SIMULACIÓN DE DATOS DEL USUARIO LOGUEADO (DEBE VENIR DE ISAR TRAS EL LOGIN)
  String get currentUserRoleName => 'global_admin';
  String? get currentUserCompanyId => null;
  // -------------------------------------------------------------------

  // Estado para la gestión de usuarios
  List<UserInDB> _users = [];
  bool _isUsersLoading = false;
  String? _usersError;

  // ESTADO: Companies & Branches
  List<CompanyInDB> _companies = [];
  bool _isCompaniesLoading = false;
  String? _companiesError;

  List<BranchInDB> _currentCompanyBranches = [];
  bool _isBranchesLoading = false;
  String? _branchesError;

  // -------------------------------------------------------------------
  // GETTERS
  // -------------------------------------------------------------------

  List<UserInDB> get users => _users;
  bool get isUsersLoading => _isUsersLoading;
  String? get usersError => _usersError;

  List<CompanyInDB> get companies => _companies;
  bool get isCompaniesLoading => _isCompaniesLoading;
  String? get companiesError => _companiesError;

  List<BranchInDB> get currentCompanyBranches => _currentCompanyBranches;
  bool get isBranchesLoading => _isBranchesLoading;
  String? get branchesError => _branchesError;

  AppSection get currentSection => _currentSection;

  void setSection(AppSection section) {
    if (_currentSection != section) {
      _currentSection = section;
      notifyListeners();

      // Cargar datos al cambiar de sección
      switch (section) {
        case AppSection.users:
          fetchUsers(); // ⬅️ Usa el flujo del Repositorio (Cache-First)
          break;
        case AppSection.companies:
          fetchCompanies(); // ⬅️ Usa el flujo del Repositorio (Cache-First)
          break;
        default:
          break;
      }
    }
  }

  // -------------------------------------------------------------------
  // USUARIOS: CRUD (Usa PlatformRepository)
  // -------------------------------------------------------------------
  // 1. fetchUsers (Cache-First + Filtrado Local por Rol)
  Future<void> fetchUsers() async {
    if (_isUsersLoading) return;

    _isUsersLoading = true;
    _usersError = null;
    notifyListeners();

    try {
      // Aplicamos el filtro de compañía al Repositorio (para el llamado a la API)
      final String? companyFilter =
          currentUserRoleName == 'global_admin' ? null : currentUserCompanyId;

      // OBTENER DEL REPOSITORIO (Lógica Cache-First)
      final fetchedUsers = await _platformRepository.getUsers(
        companyId: companyFilter,
      );

      // Aplicar las restricciones de visibilidad del Admin Logueado (para modo offline)
      if (currentUserRoleName == 'global_admin') {
        _users = fetchedUsers;
      } else if (currentUserRoleName == 'company_admin' &&
          companyFilter != null) {
        // Un company_admin solo ve usuarios de su compañía.
        _users =
            fetchedUsers.where((u) => u.companyId == companyFilter).toList();
      } else {
        // Roles inferiores no gestionan usuarios
        _users = [];
      }
    } catch (e) {
      _usersError = 'Error al cargar usuarios: $e';
    } finally {
      _isUsersLoading = false;
      notifyListeners();
    }
  }

  /// Crea un nuevo usuario y añade el resultado a la lista local.
  Future<void> createUser(UserCreate user) async {
    _usersError = null;
    try {
      // USA REPOSITORIO (API-First, Write-Through)
      final newUser = await _platformRepository.createUser(user);
      _users.add(newUser);
      notifyListeners();
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// Actualiza un usuario existente y actualiza la lista local.
  Future<void> updateUser(String userId, UserUpdate updateData) async {
    _usersError = null;
    try {
      // USA REPOSITORIO (API-First, Write-Through)
      final updatedUser = await _platformRepository.updateUser(
        userId,
        updateData,
      );

      // Buscar y reemplazar el usuario en la lista
      final index = _users.indexWhere((u) => u.id == userId);
      if (index != -1) {
        _users[index] = updatedUser;
        notifyListeners();
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // -------------------------------------------------------------------
  // COMPANIES: CRUD (Usa PlatformRepository)
  // -------------------------------------------------------------------

  Future<void> fetchCompanies() async {
    if (_isCompaniesLoading) return;

    _isCompaniesLoading = true;
    _companiesError = null;
    notifyListeners();

    try {
      // OBTENER DEL REPOSITORIO (Lógica Cache-First)
      final allCompanies = await _platformRepository.getCompanies();

      // Lógica de filtrado por rol
      if (currentUserRoleName == 'global_admin') {
        _companies = allCompanies;
      } else if (currentUserRoleName == 'company_admin' &&
          currentUserCompanyId != null) {
        _companies =
            allCompanies.where((c) => c.id == currentUserCompanyId).toList();

        if (_companies.isEmpty) {
          throw Exception(
            "No se encontró la compañía asignada al administrador.",
          );
        }
      } else {
        _companies = [];
      }

      // Cargar sucursales de la primera compañía (si existe)
      if (_companies.isNotEmpty) {
        await fetchBranches(_companies.first.id);
      }
    } catch (e) {
      _companiesError = 'Error al cargar compañías: $e';
    } finally {
      _isCompaniesLoading = false;
      notifyListeners();
    }
  }

  Future<void> createCompany(CompanyCreate company) async {
    if (currentUserRoleName != 'global_admin') {
      throw Exception(
        "Permiso denegado. Solo Global Admin puede crear compañías.",
      );
    }
    try {
      // LLAMA AL REPOSITORIO para la creación (API-First, Write-Through)
      final newCompany = await _platformRepository.createCompany(company);
      _companies.add(newCompany);
      notifyListeners();
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<void> updateCompany(String companyId, CompanyUpdate updateData) async {
    if (currentUserRoleName != 'global_admin') {
      throw Exception(
        "Permiso denegado. Solo Global Admin puede actualizar compañías.",
      );
    }
    try {
      final updatedCompany = await _platformRepository.updateCompany(
        companyId,
        updateData,
      );

      final index = _companies.indexWhere((c) => c.id == companyId);
      if (index != -1) {
        _companies[index] = updatedCompany;
        notifyListeners();
      }
    } catch (e) {
      throw Exception(e);
    }
  }

  // -------------------------------------------------------------------
  // BRANCHES: CRUD (Usa PlatformRepository)
  // -------------------------------------------------------------------

  /// Obtiene y devuelve la lista de sucursales para un companyId específico.
  Future<List<BranchInDB>> fetchBranches(String companyId) async {
    // Si es company_admin, verificar que la ID solicitada sea la suya.
    if (currentUserRoleName == 'company_admin' &&
        companyId != currentUserCompanyId) {
      _branchesError = 'Acceso denegado a sucursales de otra compañía.';
      _currentCompanyBranches = [];
      notifyListeners();
      return [];
    }

    if (_isBranchesLoading) {
      return _currentCompanyBranches;
    }

    _isBranchesLoading = true;
    _branchesError = null;
    notifyListeners();

    try {
      // OBTENER DEL REPOSITORIO (Lógica Cache-First)
      final fetchedBranches = await _platformRepository.getBranches(companyId);

      _currentCompanyBranches = fetchedBranches;
      return fetchedBranches;
    } catch (e) {
      _branchesError = 'Error al cargar sucursales: $e';
      return [];
    } finally {
      _isBranchesLoading = false;
      notifyListeners();
    }
  }

  Future<void> createBranch(String companyId, BranchCreate branch) async {
    // Restricción: solo company_admin puede crear sucursales en su compañía.
    if (currentUserRoleName == 'company_admin' &&
        companyId != currentUserCompanyId) {
      throw Exception(
        "Permiso denegado. Solo puede crear sucursales en su compañía.",
      );
    }

    try {
      // LLAMA AL REPOSITORIO para la creación (API-First, Write-Through)
      final newBranch = await _platformRepository.createBranch(
        companyId,
        branch,
      );

      // Solo añadimos si la nueva sucursal pertenece a la compañía que estamos viendo actualmente.
      if (companyId == (_companies.isNotEmpty ? _companies.first.id : null) ||
          currentUserRoleName == 'global_admin') {
        _currentCompanyBranches.add(newBranch);
      }
      notifyListeners();
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<void> updateBranch(
    String companyId,
    String branchId,
    BranchUpdate updateData,
  ) async {
    // Restricción: solo company_admin puede actualizar sucursales en su compañía.
    if (currentUserRoleName == 'company_admin' &&
        companyId != currentUserCompanyId) {
      throw Exception(
        "Permiso denegado. Solo puede actualizar sucursales en su compañía.",
      );
    }

    try {
      final updatedBranch = await _platformRepository.updateBranch(
        companyId,
        branchId,
        updateData,
      );

      // Actualizar la lista de sucursales si estamos viendo la compañía correcta
      if (companyId == (_companies.isNotEmpty ? _companies.first.id : null) ||
          currentUserRoleName == 'global_admin') {
        final index = _currentCompanyBranches.indexWhere(
          (b) => b.id == branchId,
        );
        if (index != -1) {
          _currentCompanyBranches[index] = updatedBranch;
        }
      }
      notifyListeners();
    } catch (e) {
      throw Exception(e);
    }
  }

  // -------------------------------------------------------------------
  // SECTIONS DATA
  // -------------------------------------------------------------------
  static Map<AppSection, Map<String, dynamic>> sectionData = {
    AppSection.dashboard: {'name': 'Dashboard', 'icon': Icons.dashboard},
    AppSection.pos: {'name': 'Punto de Venta', 'icon': Icons.point_of_sale},
    AppSection.inventory: {'name': 'Inventario', 'icon': Icons.inventory_2},
    AppSection.users: {'name': 'Usuarios', 'icon': Icons.people},
    AppSection.companies: {'name': 'Compañías', 'icon': Icons.apartment},
    AppSection.settings: {'name': 'Configuración', 'icon': Icons.settings},
  };
}
