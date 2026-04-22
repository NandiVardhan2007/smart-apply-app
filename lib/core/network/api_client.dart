import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/storage_service.dart';
import 'exceptions.dart';

class ApiClient {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 300),
    ),
  );

  final _sessionExpiredController = StreamController<void>.broadcast();
  Stream<void> get onSessionExpired => _sessionExpiredController.stream;

  ApiClient() {
    _dio.interceptors.add(LogInterceptor(responseBody: true, requestBody: true));
    
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final storage = StorageService();
          final token = await storage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.post(path, data: data, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters, Options? options}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> put(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.put(path, data: data, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> patch(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.patch(path, data: data, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> delete(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.delete(path, data: data, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// NEW: Stream request for real-time JARVIS output
  Stream<String> postStream(String path, {dynamic data}) async* {
    try {
      final response = await _dio.post<ResponseBody>(
        path,
        data: data,
        options: Options(responseType: ResponseType.stream),
      );

      if (response.statusCode != 200) {
        throw Exception("Streaming failed: ${response.statusCode}");
      }

      await for (final chunk in response.data!.stream) {
        yield utf8.decode(chunk);
      }
    } catch (e) {
      if (e is DioException) {
        throw _handleError(e);
      }
      rethrow;
    }
  }

  /// Upload a file with optional form fields via multipart/form-data.
  /// [filePath] is the local path to the file.
  /// [fileFieldName] is the form field name for the file (default: 'file').
  /// [fields] are optional additional form fields to include.
  Future<Response> uploadFile(
    String path, {
    required String filePath,
    required String fileName,
    String fileFieldName = 'file',
    Map<String, String>? fields,
  }) async {
    try {
      final formData = FormData.fromMap({
        fileFieldName: await MultipartFile.fromFile(filePath, filename: fileName),
        if (fields != null) ...fields,
      });

      return await _dio.post(
        path,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 180),
        ),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Upload raw file bytes with optional form fields via multipart/form-data.
  Future<Response> uploadFileBytes(
    String path, {
    required List<int> fileBytes,
    required String fileName,
    String fileFieldName = 'file',
    Map<String, String>? fields,
  }) async {
    try {
      final formData = FormData.fromMap({
        fileFieldName: MultipartFile.fromBytes(fileBytes, filename: fileName),
        if (fields != null) ...fields,
      });

      return await _dio.post(
        path,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 180),
        ),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout || 
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Check your internet/VPN.';
    }
    
    if (error.type == DioExceptionType.connectionError) {
      return 'Could not connect to server. Ensure backend is running at ${ApiConstants.baseUrl}';
    }

    if (error.response != null) {
      if (error.response?.statusCode == 401) {
        _sessionExpiredController.add(null);
        throw SessionExpiredException();
      }
      
      final data = error.response?.data;
      if (data is Map && data.containsKey('detail')) {
        return data['detail'].toString();
      }
      if (data is String && data.isNotEmpty) {
        return data;
      }
      return 'Server Error: ${error.response?.statusCode}';
    }
    
    return error.message ?? 'Unknown network error';
  }
}

final apiClient = ApiClient();
