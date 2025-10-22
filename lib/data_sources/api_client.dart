// /lib/data_sources/api_client.dart

import 'dart:convert';
import 'package:dio/dio.dart';

/// Cliente genérico que usa Dio para las llamadas API del Repositorio.
class ApiClient {
  final Dio _dio;

  ApiClient({required String baseUrl, required String authToken})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            receiveTimeout: const Duration(seconds: 15),
            connectTimeout: const Duration(seconds: 15),
          ),
        );

  /// Método genérico para solicitudes GET.
  Future<List<dynamic>> get(String path) async {
    try {
      final response = await _dio.get(path);
      if (response.statusCode == 200 && response.data != null) {
        return response.data as List<dynamic>;
      }
      throw ApiException('Respuesta inesperada del servidor.');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw NetworkException(
          "Tiempo de espera agotado. Verifique la conexión.",
        );
      }
      final statusCode = e.response?.statusCode ?? 0;
      final message = e.response?.data != null
          ? jsonEncode(e.response!.data)
          : 'Error de red con estado $statusCode.';
      throw ApiException('Error de API ($statusCode): $message');
    } catch (e) {
      throw ApiException('Error desconocido: ${e.toString()}');
    }
  }

  /// Método genérico para solicitudes POST.
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.post(path, data: body);
      if (response.statusCode == 201 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      throw ApiException('Respuesta inesperada del servidor después de POST.');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw NetworkException("Tiempo de espera agotado o sin conexión.");
      }
      final statusCode = e.response?.statusCode ?? 0;
      final message = e.response?.data != null
          ? jsonEncode(e.response!.data)
          : 'Error de red con estado $statusCode.';
      throw ApiException('Error de API ($statusCode): $message');
    } catch (e) {
      throw ApiException('Error desconocido en POST: ${e.toString()}');
    }
  }
}

// Excepciones Personalizadas (Usadas por el Repositorio)
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => 'NetworkException: $message';
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => 'ApiException: $message';
}
