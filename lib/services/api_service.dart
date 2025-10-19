// dcpos_app/lib/services/api_service.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';

// ISAR
import 'package:dcpos_app/isar_service.dart';
import 'package:dcpos_app/models/local/user_local.dart';

// MODELOS DOMINIO (SIN JSON SERIALIZABLE)
import 'package:dcpos_app/models/domain/user.dart';
import 'package:dcpos_app/models/domain/platform.dart';
// Importa auth.dart si decides usar el modelo Token
// import 'package:dcpos_app/models/domain/auth.dart';

// Usaremos localhost para desarrollo en escritorio. ¡Asegúrate de que FastAPI esté corriendo!
// Para Android Emulator: 'http://10.0.2.2:8000/api/v1'
const String _baseUrl = 'http://localhost:8000/api/v1';

class ApiService {
  final Dio _dio = Dio();
  final IsarService _isarService;

  ApiService(this._isarService) {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);

    // Añadir interceptor para inyectar el token JWT automáticamente
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Excluir rutas de autenticación de la inyección de token
          if (!options.path.contains('/auth/login') &&
              !options.path.contains('/auth/register')) {
            final isar = await _isarService.db;
            // Intenta obtener el token del usuario activo (id=1)
            final user = await isar.userLocals.get(1);

            if (user?.jwtToken != null) {
              // Añadir token si está disponible
              options.headers['Authorization'] = 'Bearer ${user!.jwtToken}';
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
            // Aquí se puede añadir la lógica de logout automático si es necesario
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
          // Devuelve el primer mensaje de error de validación
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
  // A. Endpoints de Autenticación y Perfil
  // -------------------------------------------------------------------

  /// POST /api/v1/auth/login
  Future<UserLocal> login({
    required String username,
    required String password,
  }) async {
    final dataToSend = {'username': username, 'password': password};

    try {
      final response = await _dio.post('/auth/login', data: dataToSend);

      final token = response.data['access_token'] as String;
      // El rol lo obtienes de la respuesta del token
      final roleName = response.data['role'] as String;

      // Obtener datos del usuario con el nuevo token (GET /auth/me)
      final userMeResponse = await _dio.get(
        '/auth/me',
        options: Options(
          headers: {
            // Se inyecta manualmente el token para la llamada inmediata
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final userData = userMeResponse.data;

      // Mapear y guardar el usuario localmente en Isar
      final user = UserLocal()
        ..id =
            1 // Usamos un ID fijo para el usuario activo
        ..username = userData['username']
        ..jwtToken = token
        ..roleName =
            roleName // Usamos el rol de la respuesta del token
        ..companyId = userData['company_id']?.toString()
        ..isActive = userData['is_active'];

      final isar = await _isarService.db;
      await isar.writeTxn(() async {
        await isar.userLocals.clear(); // Limpia sesiones anteriores
        await isar.userLocals.put(user);
      });

      return user;
    } on DioException catch (e) {
      String errorMessage = _extractErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception(
        'Ocurrió un error inesperado durante el login: ${e.toString()}',
      );
    }
  }

  /// Cierra la sesión del usuario eliminando la información local de Isar.
  Future<void> logout() async {
    try {
      if (kDebugMode) {
        print('LOGOUT: Cleaning up local user data in Isar.');
      }
      final isar = await _isarService.db;

      // Limpia la colección UserLocal, eliminando el token.
      await isar.writeTxn(() async {
        await isar.userLocals.clear();
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error during logout: $e');
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

  /// GET /api/v1/users/ (Lista usuarios con filtros opcionales)
  Future<List<UserInDB>> fetchUsers({
    String? companyId,
    String? branchId,
  }) async {
    try {
      // ✅ ARREGLO IMPLEMENTADO: Omitir parámetros nulos/vacíos para evitar error 422
      final Map<String, dynamic> queryParams = {};

      if (companyId != null && companyId.isNotEmpty) {
        queryParams['company_id'] = companyId;
      }
      if (branchId != null && branchId.isNotEmpty) {
        queryParams['branch_id'] = branchId;
      }

      final response = await _dio.get(
        '/users/',
        // Solo enviar queryParameters si hay filtros presentes
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

  /// DELETE /api/v1/users/{user_id} (Establece is_active=False)
  Future<void> deactivateUser(String userId) async {
    try {
      // El DELETE en FastAPI está mapeado a un 204 sin contenido si es exitoso
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
        // Método que elimina todos los datos y restablece las colecciones
        await isar.clear();
      });
    });
    if (kDebugMode) {
      print('DEBUG: Isar Database cleared successfully.');
    }
  }
}
