// dcpos_app/lib/services/api_service.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:dcpos_app/isar_service.dart';
// ¡RUTA CORREGIDA!
import 'package:dcpos_app/models/local/user_local.dart';
// ¡RUTA CORREGIDA!
import 'package:dcpos_app/models/domain/user.dart';

// Usaremos localhost para desarrollo en escritorio
const String _baseUrl = 'http://localhost:8000/api/v1';
// Para Android Emulator: 'http://10.0.2.2:8000/api/v1'

class ApiService {
  final Dio _dio = Dio();
  final IsarService _isarService;

  ApiService(this._isarService) {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);

    // Añadir interceptor para añadir el token automáticamente a peticiones que NO sean de login
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Si la ruta no es la de login, intentamos añadir el token
          if (!options.path.contains('/auth/login') &&
              !options.path.contains('/auth/token')) {
            final isar = await _isarService.db;
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
            print('Authentication Error (401): Token expired or invalid.');
            // Aquí se puede añadir la lógica de logout automático
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
      // 1. Manejo de errores de validación (422) de FastAPI con lista de detalles
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
  // Endpoints de Autenticación
  // -------------------------------------------------------------------

  /// Endpoint de Login: POST /api/v1/auth/login (JSON)
  Future<UserLocal> login({
    required String username,
    required String password,
  }) async {
    // Usamos /auth/login ya que esperamos JSON
    final dataToSend = {'username': username, 'password': password};

    try {
      final response = await _dio.post(
        '/auth/login', // CAMBIO DE RUTA: Login
        data: dataToSend, // Dio enviará esto como JSON por defecto
        // NO ES NECESARIO Options(contentType: Headers.jsonContentType)
        // ya que es el comportamiento predeterminado de dio con un mapa.
      );

      final token = response.data['access_token'];

      // Obtener datos del usuario con el nuevo token
      final userMeResponse = await _dio.get(
        '/auth/me',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          }, // Sobreescribimos el token SOLO para esta llamada
        ),
      );

      // Mapear y guardar el usuario localmente
      final user = UserLocal()
        ..id = 1
        ..username = userMeResponse.data['username']
        ..jwtToken = token
        ..roleName = userMeResponse.data['role_name']
        ..companyId = userMeResponse.data['company_id']?.toString()
        ..isActive = userMeResponse.data['is_active'];

      final isar = await _isarService.db;
      await isar.writeTxn(() async {
        await isar.userLocals.clear();
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

  // -------------------------------------------------------------------
  // Endpoints de Datos (Autenticados)
  // -------------------------------------------------------------------

  /// Endpoint: GET /api/v1/users/ (Lista de usuarios)
  Future<List<User>> fetchUsers() async {
    try {
      // El interceptor añadirá el token automáticamente si el usuario está logueado
      final response = await _dio.get('/users/');

      // Mapear la lista de JSON a la lista de objetos User
      List<dynamic> userList = response.data;
      return userList.map((json) => User.fromJson(json)).toList();
    } on DioException catch (e) {
      String errorMessage = _extractErrorMessage(e);
      throw Exception(errorMessage);
    }
  }

  /// Cierra la sesión del usuario eliminando la información local de Isar.
  Future<void> logout() async {
    try {
      if (kDebugMode) {
        print('LOGOUT: Cleaning up local user data in Isar.');
      }
      final isar = await _isarService.db;

      // Limpia toda la colección UserLocal, eliminando el token.
      await isar.writeTxn(() async {
        await isar.userLocals.clear();
      });

      // Nota: Si usas AppStateProvider para manejar el estado de la UI,
      // debes notificarlo después de llamar a esta función.
    } catch (e) {
      if (kDebugMode) {
        print('Error during logout: $e');
      }
      // Se puede ignorar o registrar el error, ya que la meta es borrar.
    }
  }
}
