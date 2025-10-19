// dcpos_app/lib/providers/app_state_provider.dart

import 'package:flutter/material.dart';
// Importa el servicio y los modelos
import 'package:dcpos_app/main.dart';
import 'package:dcpos_app/models/domain/user.dart';
// NUEVA IMPORTACIÓN: Modelos de Compañía y Sucursal
import 'package:dcpos_app/models/domain/platform.dart';

// NUEVO ENUM: Añadir 'companies'
enum AppSection { dashboard, pos, inventory, users, companies, settings }

class AppStateProvider with ChangeNotifier {
  // Cambiado el inicio para probar Companies
  AppSection _currentSection = AppSection.companies;

  // ⚠️ SIMULACIÓN DE DATOS DEL USUARIO LOGUEADO
  // ESTO HA SIDO MODIFICADO PARA SIMULAR UN GLOBAL_ADMIN
  String get currentUserRoleName =>
      'global_admin'; // ⬅️ CAMBIO: Ahora simula un Global Admin
  String? get currentUserCompanyId =>
      null; // ⬅️ CAMBIO: El Global Admin no tiene Company ID
  // -------------------------------------------------------------------

  // Estado para la gestión de usuarios
  List<UserInDB> _users = [];
  bool _isUsersLoading = false;
  String? _usersError;

  // -------------------------------------------------------------------
  // ESTADO: Companies & Branches
  // -------------------------------------------------------------------
  List<CompanyInDB> _companies = [];
  bool _isCompaniesLoading = false;
  String? _companiesError;

  List<BranchInDB> _currentCompanyBranches = [];
  bool _isBranchesLoading = false;
  String? _branchesError;
  // -------------------------------------------------------------------

  List<UserInDB> get users => _users;
  bool get isUsersLoading => _isUsersLoading;
  String? get usersError => _usersError;

  // NUEVOS GETTERS
  List<CompanyInDB> get companies => _companies;
  bool get isCompaniesLoading => _isCompaniesLoading;
  String? get companiesError => _companiesError;

  List<BranchInDB> get currentCompanyBranches => _currentCompanyBranches;
  bool get isBranchesLoading => _isBranchesLoading;
  String? get branchesError => _branchesError;

  // Propiedad existente
  AppSection get currentSection => _currentSection;

  void setSection(AppSection section) {
    if (_currentSection != section) {
      _currentSection = section;
      notifyListeners();

      // Cargar datos al cambiar de sección
      switch (section) {
        case AppSection.users:
          fetchUsers();
          break;
        case AppSection.companies:
          fetchCompanies();
          break;
        default:
          break;
      }
    }
  }

  // -------------------------------------------------------------------
  // USUARIOS: CRUD
  // -------------------------------------------------------------------
  Future<void> fetchUsers() async {
    if (_isUsersLoading) return;

    _isUsersLoading = true;
    _usersError = null;
    notifyListeners();

    try {
      final fetchedUsers = await apiService.fetchUsers();
      _users = fetchedUsers;
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
      final newUser = await apiService.createUser(user);
      _users.add(newUser);
      notifyListeners();
    } catch (e) {
      // Relanzamos la excepción para que el modal de la UI capture el error
      throw Exception(e.toString());
    }
  }

  /// Actualiza un usuario existente (incluyendo isActive) y actualiza la lista local.
  Future<void> updateUser(String userId, UserUpdate updateData) async {
    _usersError = null;
    try {
      final updatedUser = await apiService.updateUser(userId, updateData);

      // Buscar y reemplazar el usuario en la lista
      final index = _users.indexWhere((u) => u.id == userId);
      if (index != -1) {
        _users[index] = updatedUser;
        notifyListeners();
      }
    } catch (e) {
      // Relanzamos la excepción para que la UI capture el error
      throw Exception(e.toString());
    }
  }

  // -------------------------------------------------------------------
  // COMPANIES: CRUD (LÓGICA DE VISIBILIDAD POR ROL)
  // -------------------------------------------------------------------

  Future<void> fetchCompanies() async {
    if (_isCompaniesLoading) return;

    _isCompaniesLoading = true;
    _companiesError = null;
    notifyListeners();

    try {
      final allCompanies = await apiService.fetchCompanies();

      if (currentUserRoleName == 'global_admin') {
        // Global Admin: Ve TODAS las compañías
        _companies = allCompanies;
      } else if (currentUserRoleName == 'company_admin' &&
          currentUserCompanyId != null) {
        // Company Admin: Ve SOLO su compañía
        _companies = allCompanies
            .where((c) => c.id == currentUserCompanyId)
            .toList();

        if (_companies.isEmpty) {
          throw Exception(
            "No se encontró la compañía asignada al administrador.",
          );
        }
      } else {
        // Otros roles o company_admin sin ID: No ve compañías
        _companies = [];
      }

      // Cargar las sucursales de la compañía seleccionada por defecto (la primera en la lista filtrada)
      if (_companies.isNotEmpty) {
        // Llama a fetchBranches, que actualiza _currentCompanyBranches
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
      final newCompany = await apiService.createCompany(company);
      _companies.add(newCompany);
      notifyListeners();
    } catch (e) {
      // Re-lanza la excepción para que el UI pueda mostrar el error en el modal
      throw Exception(e);
    }
  }

  // -------------------------------------------------------------------
  // BRANCHES: CRUD
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
      // 1. Llama al servicio y obtiene el resultado.
      final fetchedBranches = await apiService.fetchBranches(companyId);

      // 2. Actualiza el estado interno del Provider.
      _currentCompanyBranches = fetchedBranches;

      // 3. RETORNA la lista.
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

    // Global admin puede crear sucursales en cualquier compañía (si companyId es válido)

    try {
      final newBranch = await apiService.createBranch(companyId, branch);
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
