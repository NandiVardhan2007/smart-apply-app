import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';


/// API service for the LinkedIn Auto Applier feature.
/// Handles all network calls to the backend LinkedIn applier endpoints.
class LinkedInApplierService {
  final ApiClient _client = apiClient;

  /// Generate AI-powered search terms from user profile data.
  Future<Map<String, dynamic>> generateSearchTerms({
    String? resumeText,
    String? skills,
    String? experience,
    String? education,
    String? location,
    Map<String, dynamic>? jobPreferences,
  }) async {
    final response = await _client.post(
      ApiConstants.applierSearchTerms,
      data: {
        'resume_text': resumeText,
        'skills': skills,
        'experience': experience,
        'education': education,
        'location': location,
        'job_preferences': jobPreferences ?? {},
      },
    );
    return Map<String, dynamic>.from(response.data);
  }

  /// Ask AI to answer a LinkedIn application question.
  Future<Map<String, dynamic>> answerQuestion({
    required String question,
    String questionType = 'text',
    List<String>? options,
    String? jobTitle,
    String? companyName,
    String? jobDescription,
    bool useSmartSelection = false,
  }) async {
    final response = await _client.post(
      ApiConstants.applierAnswerQuestion,
      data: {
        'question': question,
        'question_type': questionType,
        'options': options,
        'job_title': jobTitle,
        'company_name': companyName,
        'job_description': jobDescription,
        'use_smart_selection': useSmartSelection,
      },
    );
    return Map<String, dynamic>.from(response.data);
  }

  /// Save a user-provided answer to memory.
  Future<Map<String, dynamic>> saveAnswer({
    required String question,
    required String answer,
    String? jobTitle,
    String? companyName,
    String questionType = 'text',
  }) async {
    final response = await _client.post(
      ApiConstants.applierSaveAnswer,
      data: {
        'question': question,
        'answer': answer,
        'job_title': jobTitle,
        'company_name': companyName,
        'question_type': questionType,
      },
    );
    return Map<String, dynamic>.from(response.data);
  }

  /// Log an application attempt.
  Future<Map<String, dynamic>> logApplication({
    required String jobTitle,
    required String companyName,
    required String jobUrl,
    String status = 'applied',
    String? notes,
    int questionsAnswered = 0,
    int questionsManual = 0,
  }) async {
    final response = await _client.post(
      ApiConstants.applierLogApplication,
      data: {
        'job_title': jobTitle,
        'company_name': companyName,
        'job_url': jobUrl,
        'status': status,
        'notes': notes,
        'questions_answered': questionsAnswered,
        'questions_manual': questionsManual,
      },
    );
    return Map<String, dynamic>.from(response.data);
  }

  /// Get application history.
  Future<Map<String, dynamic>> getHistory({int limit = 50}) async {
    final response = await _client.get(
      ApiConstants.applierHistory,
      queryParameters: {'limit': limit},
    );
    return Map<String, dynamic>.from(response.data);
  }

  /// Get today's stats.
  Future<Map<String, dynamic>> getStats() async {
    final response = await _client.get(ApiConstants.applierStats);
    return Map<String, dynamic>.from(response.data);
  }

  /// Report an automation error with logs and screenshot.
  Future<Map<String, dynamic>> reportError({
    required String errorMessage,
    String? jobTitle,
    String? jobUrl,
    String action = 'unknown',
    String? stackTrace,
    String? screenshotBase64,
    Map<String, dynamic>? webviewState,
  }) async {
    final response = await _client.post(
      '${ApiConstants.applier}/report-error',
      data: {
        'error_message': errorMessage,
        'job_title': jobTitle,
        'job_url': jobUrl,
        'action': action,
        'stack_trace': stackTrace,
        'screenshot_base64': screenshotBase64,
        'webview_state': webviewState ?? {},
      },
    );
    return Map<String, dynamic>.from(response.data);
  }

  /// Get saved Q&A answers.
  Future<Map<String, dynamic>> getSavedAnswers() async {
    final response = await _client.get(ApiConstants.applierSavedAnswers);
    return Map<String, dynamic>.from(response.data);
  }

  /// Fetch user profile data for search term generation.
  Future<Map<String, dynamic>> getUserProfile() async {
    final response = await _client.get(ApiConstants.profile);
    return Map<String, dynamic>.from(response.data);
  }

  /// Collect a question for global bank analysis.
  Future<Map<String, dynamic>> collectQuestion({
    required String question,
    String questionType = 'text',
    List<String>? options,
    String? jobTitle,
    String? companyName,
  }) async {
    final response = await _client.post(
      '${ApiConstants.applier}/collect-question',
      data: {
        'question': question,
        'question_type': questionType,
        'options': options,
        'job_title': jobTitle,
        'company_name': companyName,
      },
    );
    return Map<String, dynamic>.from(response.data);
  }
}

