// dcpos_app/lib/services/api_service.dart (Código completo con correcciones)

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

// ISAR
import 'package:dcpos_app/isar_service.dart';
import 'package:dcpos_app/models/local/user_local.dart';

// MODELOS DOMINIO
import 'package:dcpos_app/models/domain/user.dart';
import 'package:dcpos_app/models/domain/platform.dart';
import 'package:dcpos_app/models/domain/company_update.dart';

import 'package:dcpos_app/models/domain/branch_update.dart';
import 'package:dcpos_app/data_sources/local_user_data_source.dart';
import 'package:isar/isar.dart';

// Para Android Emulator: 'http://10.0.2.2:8000/api/v1'
const String _baseUrl = 'http://localhost:8000/api/v1';

class ApiService {
  final Dio _dio = Dio();
  final IsarService _isarService;
  final LocalUserDataSource? _localUserDataSource;

  // 💡 CORRECCIÓN CRÍTICA: Almacena el token más reciente en memoria
  String? _latestToken;

  ApiService(this._isarService, {LocalUserDataSource? localUserDataSource})
      : _localUserDataSource = localUserDataSource {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);

    // Interceptor para inyectar el token JWT automáticamente
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!options.path.contains('/auth/login')) {
            String? token;

            // 1. Intentar usar el token en memoria (más rápido y garantiza la inmediatez post-login)
            if (_latestToken != null) {
              token = _latestToken;
            } else {
              // 2. Si no hay token en memoria, leer de Isar (para re-apertura de app o sesión offline)
              final isar = await _isarService.db;
              final user = await isar.userLocals.get(1);
              token = user?.jwtToken;
            }

            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }

          if (kDebugMode) {
            print('DIO REQUEST: ${options.method} ${options.uri}');
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          if (e.response?.statusCode == 401) {
            if (kDebugMode) {
              print('Authentication Error (401): Token expired or invalid.');
            }
            // Aquí se debería gestionar un logout forzado si es necesario.
          }
          return handler.next(e);
        },
      ),
    );
  }

  // -------------------------------------------------------------------
  // Helper de Errores (para Dio)
  // -------------------------------------------------------------------

  String _extractErrorMessage(DioException e) {
    dynamic errorData = e.response?.data;
    String errorMessage = 'Error de conexión o credenciales inválidas.';

    if (errorData != null && errorData is Map<String, dynamic>) {
      // 1. Manejo de errores de validación (422) de FastAPI
      if (errorData.containsKey('detail') && errorData['detail'] is List) {
        List details = errorData['detail'];
        if (details.isNotEmpty &&
            details[0] is Map &&
            details[0].containsKey('msg')) {
          errorMessage = 'Error de validación: ${details[0]['msg']}';
        }
      }
      // 2. Manejo de errores estándar de FastAPI (401, 403, con string de detalle)
      else if (errorData.containsKey('detail') &&
          errorData['detail'] is String) {
        errorMessage = errorData['detail'];
      }
    }
    return errorMessage;
  }

  // -------------------------------------------------------------------
  // A. Endpoints de Autenticación y Perfil (Login con Fallback Offline)
  // -------------------------------------------------------------------

  /// Sincroniza la lista completa de usuarios desde la API y la guarda en Isar.
  Future<void> syncAllUsersFromApi() async {
    final isar = await _isarService.db;

    // 1. Obtener los usuarios de la API
    final apiUsers = await fetchUsers();
    if (apiUsers.isEmpty) return;

    // 2. Obtener la sesión activa (ID=1) actual.
    final currentActiveSession = await isar.userLocals.get(1);
    final activeExternalId = currentActiveSession?.externalId;
    final activeJwtToken = currentActiveSession?.jwtToken;
    final activePasswordHash = currentActiveSession?.passwordHash;

    final List<UserLocal> localUsersToPut = [];

    // 3. Mapear y asignar ID=1 y Token/Hash al usuario activo si está en la API.
    for (var apiUser in apiUsers) {
      final userLocal = UserLocal.fromApiDomain(apiUser);

      // Si este usuario de la API es el usuario logueado actualmente, forzamos ID=1
      if (activeExternalId != null && apiUser.id == activeExternalId) {
        userLocal.id = 1;
        userLocal.jwtToken = activeJwtToken;
        userLocal.passwordHash = activePasswordHash;
      }
      // Para todos los demás, el ID es 0 (Isar.autoIncrement)

      localUsersToPut.add(userLocal);
    }

    await isar.writeTxn(() async {
      // 4. LIMPIEZA: Borrar todos los usuarios EXCEPTO el ID=1
      final allNonActiveUserIds = await isar.userLocals
          .filter()
          .not()
          .idEqualTo(1) // Filtramos todos los IDs EXCEPTO el 1
          .findAll()
          .then((users) => users.map((u) => u.id).toList());

      if (allNonActiveUserIds.isNotEmpty) {
        await isar.userLocals.deleteAll(allNonActiveUserIds);
      }

      // 5. Insertar/Actualizar todos los usuarios.
      await isar.userLocals.putAllByExternalId(localUsersToPut);
    });
  }

  /// POST /api/v1/auth/login
  Future<UserLocal> login({
    required String username,
    required String password,
  }) async {
    final dataToSend = {'username': username, 'password': password};
    final isar = await _isarService.db;

    try {
      // =================================================================
      // 1. INTENTO DE LOGIN ONLINE (API)
      // =================================================================
      final response = await _dio.post('/auth/login', data: dataToSend);

      final token = response.data['access_token'] as String;
      final roleName = response.data['role'] as String;

      // 💡 CORRECCIÓN: Almacenar token en memoria inmediatamente
      _latestToken = token;

      // Obtener datos del usuario con el nuevo token (GET /auth/me)
      final userMeResponse = await _dio.get(
        '/auth/me',
        // Opciones para asegurar que usa el token recién obtenido (el Interceptor ya lo haría, pero es más seguro)
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final userData = userMeResponse.data;
      final externalUserId = userData['id'].toString();

      // Mapear y preparar el objeto (ID=0 por defecto)
      final userToSync = UserLocal()
        ..externalId = externalUserId
        ..username = userData['username']
        ..jwtToken = token // El token es esencial
        ..roleId = userData['role_id'] as int
        ..roleName = roleName
        ..companyId = userData['company_id']?.toString()
        ..branchId = userData['branch_id']?.toString()
        ..isActive = userData['is_active']
        ..passwordHash = password; // GUARDAMOS LA CONTRASEÑA

      await isar.writeTxn(() async {
        // 1. Buscar si el usuario ya existe localmente
        final existingUser = await isar.userLocals
            .filter()
            .externalIdEqualTo(externalUserId)
            .findFirst();

        // 2. Crear o actualizar la Sesión Activa (ID=1)
        final activeSession = userToSync.copyWith(id: 1, jwtToken: token);

        // A. Si el usuario existe, borramos el registro con su ID auto-incremental (Id > 1).
        if (existingUser != null) {
          if (existingUser.id != 1) {
            await isar.userLocals.delete(existingUser.id);
          }
        }

        // B. Insertamos el nuevo registro de sesión en el ID fijo (1).
        await isar.userLocals.put(activeSession);
      });

      // Retornar el objeto de sesión activa
      return userToSync.copyWith(id: 1);
    } on DioException catch (e) {
      // =================================================================
      // 2. LÓGICA DE LOGIN OFFLINE (FALLBACK)
      // =================================================================

      final isConnectionError = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.unknown;

      if (isConnectionError) {
        if (kDebugMode) {
          print('Error de conexión. Intentando Login Offline...');
        }

        final localUserMatch = await isar.userLocals
            .filter()
            .usernameEqualTo(username)
            .findFirst();

        // VERIFICACIÓN DE CREDENCIALES OFFLINE:
        if (localUserMatch != null &&
            localUserMatch.passwordHash != null &&
            localUserMatch.passwordHash == password) {
          if (kDebugMode) {
            print(
                'LOGIN OFFLINE EXITOSO para $username. Usando datos locales.');
          }

          // Establecer la sesión activa en ID=1 con los datos conservados.
          final activeSession = localUserMatch.copyWith(
            id: 1,
            jwtToken: localUserMatch.jwtToken, // Reusar el token si existe
          );

          // 💡 CORRECCIÓN: Almacenar token en memoria para el Interceptor, incluso si es viejo.
          _latestToken = localUserMatch.jwtToken;

          await isar.writeTxn(() async {
            if (localUserMatch.id != 1) {
              await isar.userLocals.delete(localUserMatch.id);
            }
            await isar.userLocals.put(activeSession);
          });

          return activeSession;
        }

        throw Exception(
          'Error de conexión. No hay datos de sesión previa o credenciales inválidas.',
        );
      }

      String errorMessage = _extractErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception(
        'Ocurrió un error inesperado durante el login: ${e.toString()}',
      );
    }
  }

  /// Cierra la sesión del usuario.
  Future<void> logout() async {
    try {
      if (kDebugMode) {
        print('LOGOUT: Cleaning up token from local user data in Isar (ID=1).');
      }

      // 💡 CORRECCIÓN: Anular el token en memoria inmediatamente
      _latestToken = null;

      final isar = await _isarService.db;
      final sessionUser = await isar.userLocals.get(1);

      if (sessionUser != null) {
        final userWithoutToken = sessionUser.copyWith(
          jwtToken: null,
        );

        await isar.writeTxn(() async {
          await isar.userLocals.put(userWithoutToken);
        });

        if (kDebugMode) {
          print('LOGOUT LOCAL SUCCESSFUL: jwtToken set to null in ID=1.');
        }
      } else {
        if (kDebugMode) {
          print('LOGOUT WARNING: No active session found (ID=1).');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during local logout transaction: $e');
      }
    }
  }

  /// GET /api/v1/auth/me
  Future<UserInDB> fetchCurrentUser() async {
    try {
      final response = await _dio.get('/auth/me');
      return UserInDB.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  // -------------------------------------------------------------------
  // B. Endpoints de User Management (CRUD)
  // -------------------------------------------------------------------

  /// GET /api/v1/users/
  Future<List<UserInDB>> fetchUsers({
    String? companyId,
    String? branchId,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {};

      if (companyId != null && companyId.isNotEmpty) {
        queryParams['company_id'] = companyId;
      }
      if (branchId != null && branchId.isNotEmpty) {
        queryParams['branch_id'] = branchId;
      }

      final response = await _dio.get(
        '/users/',
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      return (response.data as List)
          .map((json) => UserInDB.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  /// GET /api/v1/users/{user_id}
  Future<UserInDB> fetchUser(String userId) async {
    try {
      final response = await _dio.get('/users/$userId');
      return UserInDB.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  /// POST /api/v1/users/
  Future<UserInDB> createUser(UserCreate user) async {
    try {
      final response = await _dio.post('/users/', data: user.toJson());
      return UserInDB.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  /// PATCH /api/v1/users/{user_id}
  Future<UserInDB> updateUser(String userId, UserUpdate user) async {
    try {
      final response = await _dio.patch('/users/$userId', data: user.toJson());
      return UserInDB.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  /// DELETE /api/v1/users/{user_id}
  Future<void> deactivateUser(String userId) async {
    try {
      await _dio.delete('/users/$userId');
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  // -------------------------------------------------------------------
  // C. Endpoints de Platform Management (Companies)
  // -------------------------------------------------------------------

  /// GET /api/v1/platform/companies
  Future<List<CompanyInDB>> fetchCompanies() async {
    try {
      final response = await _dio.get('/platform/companies');
      return (response.data as List)
          .map((json) => CompanyInDB.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  /// GET /api/v1/platform/companies/{company_id}
  Future<CompanyInDB> fetchCompany(String companyId) async {
    try {
      final response = await _dio.get('/platform/companies/$companyId');
      return CompanyInDB.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  /// POST /api/v1/platform/companies
  Future<CompanyInDB> createCompany(CompanyCreate company) async {
    try {
      final response = await _dio.post(
        '/platform/companies',
        data: company.toJson(),
      );
      return CompanyInDB.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Error al crear compañía: ${_extractErrorMessage(e)}');
    }
  }

  /// PATCH /api/v1/platform/companies/{companyId}
  Future<CompanyInDB> updateCompany(
    String companyId,
    CompanyUpdate companyUpdate,
  ) async {
    try {
      final response = await _dio.patch(
        '/platform/companies/$companyId',
        data: companyUpdate.toJson(),
      );
      return CompanyInDB.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  // -------------------------------------------------------------------
  // D. Endpoints de Platform Management (Branches)
  // -------------------------------------------------------------------

  /// GET /api/v1/platform/companies/{company_id}/branches
  Future<List<BranchInDB>> fetchBranches(String companyId) async {
    try {
      final response = await _dio.get(
        '/platform/companies/$companyId/branches',
      );
      return (response.data as List)
          .map((json) => BranchInDB.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  /// GET /api/v1/platform/companies/{company_id}/branches/{branch_id}
  Future<BranchInDB> fetchBranch(String companyId, String branchId) async {
    try {
      final response = await _dio.get(
        '/platform/companies/$companyId/branches/$branchId',
      );
      return BranchInDB.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  /// POST /api/v1/platform/companies/{company_id}/branches
  Future<BranchInDB> createBranch(String companyId, BranchCreate branch) async {
    try {
      final response = await _dio.post(
        '/platform/companies/$companyId/branches',
        data: branch.toJson(),
      );
      return BranchInDB.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  /// PATCH /api/v1/platform/companies/{company_id}/branches/{branch_id}
  Future<BranchInDB> updateBranch(
    String companyId,
    String branchId,
    BranchUpdate branchUpdate,
  ) async {
    try {
      final response = await _dio.patch(
        '/platform/companies/$companyId/branches/$branchId',
        data: branchUpdate.toJson(),
      );
      return BranchInDB.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  // -------------------------------------------------------------------
  // Z. Funciones de Mantenimiento de Datos (Limpiar Isar)
  // -------------------------------------------------------------------

  /// Elimina TODA la base de datos de Isar (útil para debug y errores de índice).
  Future<void> clearAllLocalData() async {
    if (kDebugMode) {
      print('DEBUG: Eliminando toda la base de datos local de Isar.');
    }
    await _isarService.db.then((isar) {
      return isar.writeTxn(() async {
        await isar.clear();
      });
    });
    if (kDebugMode) {
      print('DEBUG: Isar Database cleared successfully.');
    }
  }
}
