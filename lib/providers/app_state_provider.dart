import 'package:flutter/material.dart';
import 'package:dcpos_app/main.dart';
import 'package:dcpos_app/models/domain/user.dart';
import 'package:dcpos_app/models/domain/platform.dart';
import 'package:dcpos_app/repositories/platform_repository.dart'; // ⬅️ NUEVA DEPENDENCIA

// NUEVO ENUM: Añadir 'companies'
enum AppSection { dashboard, pos, inventory, users, companies, settings }

class AppStateProvider with ChangeNotifier {
  // -------------------------------------------------------------------
  // DEPENDENCIA INYECTADA
  // -------------------------------------------------------------------
  final PlatformRepository _platformRepository;

  AppStateProvider({required PlatformRepository platformRepository})
    : _platformRepository = platformRepository {
    // Inicializar la carga si la sección es 'companies' al inicio
    if (_currentSection == AppSection.companies) {
      fetchCompanies();
    }
  }

  // -------------------------------------------------------------------
  // ESTADO DE LA APLICACIÓN
  // -------------------------------------------------------------------
  AppSection _currentSection = AppSection.companies;

  // ⚠️ SIMULACIÓN DE DATOS DEL USUARIO LOGUEADO
  // Esto debería ser reemplazado por la lectura de Isar en un flujo de autenticación real.
  String get currentUserRoleName =>
      'global_admin'; // Global Admin para pruebas de Compañías
  String? get currentUserCompanyId =>
      null; // El Global Admin no tiene Company ID asignado
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
          // fetchUsers aún usa apiService directamente si no hay lógica offline/sync
          fetchUsers();
          break;
        case AppSection.companies:
          fetchCompanies(); // ⬅️ Usa el nuevo flujo del Repositorio
          break;
        default:
          break;
      }
    }
  }

  // -------------------------------------------------------------------
  // USUARIOS: CRUD (Usa apiService directamente)
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

  /// Actualiza un usuario existente y actualiza la lista local.
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
  // COMPANIES: CRUD (Usa PlatformRepository para lecturas/escrituras)
  // -------------------------------------------------------------------

  Future<void> fetchCompanies() async {
    if (_isCompaniesLoading) return;

    _isCompaniesLoading = true;
    _companiesError = null;
    notifyListeners();

    try {
      // 1. OBTENER DEL REPOSITORIO (Lógica Cache-First aplicada aquí)
      final allCompanies = await _platformRepository.getCompanies();

      // 2. Lógica de filtrado por rol (misma lógica que antes)
      if (currentUserRoleName == 'global_admin') {
        _companies = allCompanies;
      } else if (currentUserRoleName == 'company_admin' &&
          currentUserCompanyId != null) {
        _companies = allCompanies
            .where((c) => c.id == currentUserCompanyId)
            .toList();

        if (_companies.isEmpty) {
          throw Exception(
            "No se encontró la compañía asignada al administrador.",
          );
        }
      } else {
        _companies = [];
      }

      // 3. Cargar sucursales de la primera compañía (si existe)
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
      // LLAMA AL REPOSITORIO para la creación (sólo API)
      final newCompany = await _platformRepository.createCompany(company);
      _companies.add(newCompany);
      notifyListeners();
    } catch (e) {
      // Re-lanza la excepción para que el UI pueda mostrar el error en el modal
      throw Exception(e);
    }
  }

  // -------------------------------------------------------------------
  // BRANCHES: CRUD (Usa PlatformRepository para lecturas/escrituras)
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
      // 1. OBTENER DEL REPOSITORIO (Lógica Cache-First aplicada aquí)
      final fetchedBranches = await _platformRepository.getBranches(companyId);

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

    try {
      // LLAMA AL REPOSITORIO para la creación (sólo API)
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
