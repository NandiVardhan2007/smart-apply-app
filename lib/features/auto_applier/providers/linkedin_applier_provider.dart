import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/linkedin_applier_service.dart';
import '../services/chrome_automation_service.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../../core/utils/logger_service.dart';

/// Represents the current state of the LinkedIn Auto Applier.
enum ApplierPhase {
  idle,             // Not started
  loggingIn,        // User is logging into LinkedIn
  loggedIn,         // LinkedIn session detected
  generatingTerms,  // AI is generating search terms
  browsing,         // User is browsing/searching jobs
  searching,        // Active scanning of job list
  jobOpened,        // Job details panel visible
  easyApplyDetected, // Found the Easy Apply button
  formDetected,     // Modal form is open
  questionDetected, // Active question detected
  autofillReady,    // Fields identified and ready for injection
  reviewReady,      // Form completed, waiting for final review click
  submitWaiting,    // Submission ready (USER CONFIRMATION REQUIRED)
  submitted,        // Application sent
  error,             // Failure state
}

/// Holds the complete state for the LinkedIn Auto Applier feature.
class ApplierState {
  final ApplierPhase phase;
  final bool isLinkedInLoggedIn;
  final bool isAutomating;

  // Search terms
  final List<String> searchQueries;
  final List<String> keywords;
  final List<String> jobTitles;
  final List<String> searchUrls;
  final Map<String, dynamic> filters;

  // Session stats
  final int todayApplied;
  final int todaySkipped;
  final int todayErrors;
  final int todayTotal;
  final int allTimeTotal;

  // Current job context
  final String? currentJobTitle;
  final String? currentCompany;
  final String? currentUrl;

  // Question handling
  final Map<String, dynamic>? pendingQuestion;
  final String? pendingAnswer;
  final double pendingConfidence;
  final String? pendingSource;
  final String? pendingExplanation;

  // Application history
  final List<Map<String, dynamic>> applicationHistory;

  final String selectedJobType;

  // Errors
  final String? errorMessage;

  // Loading states
  final bool isLoadingSearchTerms;
  final bool isAnsweringQuestion;
  final bool isSavingAnswer;
  final bool isLoadingStats;
  final List<String> automationLogs;
  final DateTime? lastHeartbeat;
  final bool useSmartSelection;
  final bool isChromeMode;
  final bool isChromeConnected;


  const ApplierState({
    this.phase = ApplierPhase.idle,
    this.isLinkedInLoggedIn = false,
    this.isAutomating = false,
    this.searchQueries = const [],
    this.keywords = const [],
    this.jobTitles = const [],
    this.searchUrls = const [],
    this.filters = const {},
    this.todayApplied = 0,
    this.todaySkipped = 0,
    this.todayErrors = 0,
    this.todayTotal = 0,
    this.allTimeTotal = 0,
    this.currentJobTitle,
    this.currentCompany,
    this.currentUrl,
    this.pendingQuestion,
    this.pendingAnswer,
    this.pendingConfidence = 0.0,
    this.pendingSource,
    this.pendingExplanation,
    this.applicationHistory = const [],
    this.selectedJobType = 'full-time',
    this.errorMessage,
    this.isLoadingSearchTerms = false,
    this.isAnsweringQuestion = false,
    this.isSavingAnswer = false,
    this.isLoadingStats = false,
    this.automationLogs = const [],
    this.lastHeartbeat,
    this.useSmartSelection = false,
    this.isChromeMode = true, // Default to true on supported platforms
    this.isChromeConnected = false,
  });

  ApplierState copyWith({
    ApplierPhase? phase,
    bool? isLinkedInLoggedIn,
    bool? isAutomating,
    List<String>? searchQueries,
    List<String>? keywords,
    List<String>? jobTitles,
    List<String>? searchUrls,
    Map<String, dynamic>? filters,
    int? todayApplied,
    int? todaySkipped,
    int? todayErrors,
    int? todayTotal,
    int? allTimeTotal,
    String? currentJobTitle,
    String? currentCompany,
    String? currentUrl,
    Map<String, dynamic>? pendingQuestion,
    String? pendingAnswer,
    double? pendingConfidence,
    String? pendingSource,
    String? pendingExplanation,
    List<Map<String, dynamic>>? applicationHistory,
    String? errorMessage,
    bool? isLoadingSearchTerms,
    bool? isAnsweringQuestion,
    bool? isSavingAnswer,
    bool? isLoadingStats,
    String? selectedJobType,
    List<String>? automationLogs,
    DateTime? lastHeartbeat,
    bool? useSmartSelection,
    bool? isChromeMode,
    bool? isChromeConnected,
    bool clearPendingQuestion = false,
    bool clearError = false,
    bool clearCurrentJob = false,
    bool clearLogs = false,
  }) {
    return ApplierState(
      phase: phase ?? this.phase,
      isLinkedInLoggedIn: isLinkedInLoggedIn ?? this.isLinkedInLoggedIn,
      isAutomating: isAutomating ?? this.isAutomating,
      searchQueries: searchQueries ?? this.searchQueries,
      keywords: keywords ?? this.keywords,
      jobTitles: jobTitles ?? this.jobTitles,
      searchUrls: searchUrls ?? this.searchUrls,
      filters: filters ?? this.filters,
      todayApplied: todayApplied ?? this.todayApplied,
      todaySkipped: todaySkipped ?? this.todaySkipped,
      todayErrors: todayErrors ?? this.todayErrors,
      todayTotal: todayTotal ?? this.todayTotal,
      allTimeTotal: allTimeTotal ?? this.allTimeTotal,
      currentJobTitle: clearCurrentJob ? null : (currentJobTitle ?? this.currentJobTitle),
      currentCompany: clearCurrentJob ? null : (currentCompany ?? this.currentCompany),
      currentUrl: clearCurrentJob ? null : (currentUrl ?? this.currentUrl),
      pendingQuestion: clearPendingQuestion ? null : (pendingQuestion ?? this.pendingQuestion),
      pendingAnswer: clearPendingQuestion ? null : (pendingAnswer ?? this.pendingAnswer),
      pendingConfidence: clearPendingQuestion ? 0.0 : (pendingConfidence ?? this.pendingConfidence),
      pendingSource: clearPendingQuestion ? null : (pendingSource ?? this.pendingSource),
      pendingExplanation: clearPendingQuestion ? null : (pendingExplanation ?? this.pendingExplanation),
      applicationHistory: applicationHistory ?? this.applicationHistory,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isLoadingSearchTerms: isLoadingSearchTerms ?? this.isLoadingSearchTerms,
      isAnsweringQuestion: isAnsweringQuestion ?? this.isAnsweringQuestion,
      isSavingAnswer: isSavingAnswer ?? this.isSavingAnswer,
      isLoadingStats: isLoadingStats ?? this.isLoadingStats,
      selectedJobType: selectedJobType ?? this.selectedJobType,
      automationLogs: clearLogs ? const [] : (automationLogs ?? this.automationLogs),
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
      useSmartSelection: useSmartSelection ?? this.useSmartSelection,
      isChromeMode: isChromeMode ?? this.isChromeMode,
      isChromeConnected: isChromeConnected ?? this.isChromeConnected,
    );
  }
}

/// Riverpod Notifier for managing LinkedIn Auto Applier state.
/// Uses Riverpod v3 Notifier API (not deprecated StateNotifier).
class ApplierNotifier extends Notifier<ApplierState> {
  late final LinkedInApplierService _service;
  late final ChromeAutomationService _chromeService;

  @override
  ApplierState build() {
    _service = LinkedInApplierService();
    _chromeService = ChromeAutomationService();
    
    // Listen to Chrome logs
    _chromeService.logStream.listen((log) {
      setAutomationLog(log);
    });

    return const ApplierState();
  }

  // ── LinkedIn Login Detection ──────────────────────────────────

  void setLinkedInLoggedIn(bool loggedIn) {
    state = state.copyWith(
      isLinkedInLoggedIn: loggedIn,
      phase: loggedIn ? ApplierPhase.loggedIn : ApplierPhase.loggingIn,
      clearError: true,
    );
  }

  void setSelectedJobType(String jobType) {
    state = state.copyWith(selectedJobType: jobType);
    // Automatically re-generate search terms when job type changes if we already have queries
    if (state.searchQueries.isNotEmpty) {
      generateSearchTerms(jobType: jobType);
    }
  }

  // ── Search Term Generation ────────────────────────────────────

  Future<void> generateSearchTerms({String? jobType}) async {
    state = state.copyWith(
      isLoadingSearchTerms: true,
      phase: ApplierPhase.generatingTerms,
      clearError: true,
    );

    try {
      // Fetch user profile for context
      final profile = await _service.getUserProfile();

      final result = await _service.generateSearchTerms(
        skills: profile['skills'],
        experience: profile['experience'],
        education: profile['education'],
        location: profile['location'],
        jobPreferences: jobType != null ? {'job_type': jobType} : null,
      );

      final searchQueries = List<String>.from(result['search_queries'] ?? []);
      final keywords = List<String>.from(result['keywords'] ?? []);
      final jobTitles = List<String>.from(result['job_titles'] ?? []);
      final searchUrls = List<String>.from(result['linkedin_search_urls'] ?? []);
      final filters = Map<String, dynamic>.from(result['filters'] ?? {});

      state = state.copyWith(
        searchQueries: searchQueries,
        keywords: keywords,
        jobTitles: jobTitles,
        searchUrls: searchUrls,
        filters: filters,
        isLoadingSearchTerms: false,
        phase: ApplierPhase.browsing,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingSearchTerms: false,
        errorMessage: e.toString(),
        phase: ApplierPhase.error,
      );
    }
  }

  // ── Question Handling ─────────────────────────────────────────

  Future<void> askQuestion({
    required String question,
    String questionType = 'text',
    List<String>? options,
    String? jobTitle,
    String? companyName,
    String? jobDescription,
  }) async {
    state = state.copyWith(
      isAnsweringQuestion: true,
      pendingQuestion: {
        'question': question,
        'question_type': questionType,
        'options': options,
        'job_title': jobTitle,
        'company_name': companyName,
      },
    );

    // Harvest the question for global improvement (background)
    _service.collectQuestion(
      question: question,
      questionType: questionType,
      options: options,
      jobTitle: jobTitle,
      companyName: companyName,
    ).catchError((_) => <String, dynamic>{});

    try {
      final result = await _service.answerQuestion(
        question: question,
        questionType: questionType,
        options: options,
        jobTitle: jobTitle,
        companyName: companyName,
        jobDescription: jobDescription,
        useSmartSelection: state.useSmartSelection,
      );

      final needsInput = result['needs_user_input'] == true;

      state = state.copyWith(
        isAnsweringQuestion: false,
        pendingAnswer: result['answer'],
        pendingConfidence: (result['confidence'] as num?)?.toDouble() ?? 0.0,
        pendingSource: result['source'],
        pendingExplanation: result['explanation'],
        phase: needsInput ? ApplierPhase.questionDetected : state.phase,
      );
    } catch (e) {
      state = state.copyWith(
        isAnsweringQuestion: false,
        phase: ApplierPhase.questionDetected,
        pendingExplanation: 'Error getting answer. Please answer manually.',
      );
    }
  }

  Future<void> submitUserAnswer(String answer) async {
    if (state.pendingQuestion == null) return;

    state = state.copyWith(isSavingAnswer: true);

    try {
      await _service.saveAnswer(
        question: state.pendingQuestion!['question'],
        answer: answer,
        jobTitle: state.pendingQuestion!['job_title'],
        companyName: state.pendingQuestion!['company_name'],
        questionType: state.pendingQuestion!['question_type'] ?? 'text',
      );

      state = state.copyWith(
        isSavingAnswer: false,
        clearPendingQuestion: true,
        phase: state.isAutomating ? ApplierPhase.autofillReady : ApplierPhase.browsing,
      );
    } catch (e) {
      state = state.copyWith(
        isSavingAnswer: false,
        errorMessage: 'Failed to save answer: $e',
      );
    }
  }

  void clearPendingQuestion() {
    state = state.copyWith(
      clearPendingQuestion: true,
    );
  }

  void dismissQuestion() {
    state = state.copyWith(
      clearPendingQuestion: true,
      phase: state.isAutomating ? ApplierPhase.autofillReady : ApplierPhase.browsing,
    );
  }

  void setUseSmartSelection(bool value) {
    state = state.copyWith(useSmartSelection: value);
  }

  void setChromeMode(bool value) {
    state = state.copyWith(isChromeMode: value);
    LocalLogger.log('Bridge Mode changed to: ${value ? 'CHROME' : 'WEBVIEW'}');
  }

  // ── Automation Control ────────────────────────────────────────

  void setAutomationLog(String log, {ApplierPhase? phase}) {
    LocalLogger.log('[AutoApplier] ${phase?.name ?? state.phase.name}: $log');
    
    final currentLogs = List<String>.from(state.automationLogs);
    currentLogs.add('[${DateTime.now().toString().split(' ').last.substring(0, 8)}] $log');
    
    // Keep last 100 logs for performance
    if (currentLogs.length > 100) currentLogs.removeAt(0);
    
    state = state.copyWith(
      automationLogs: currentLogs,
      phase: phase ?? state.phase,
    );
  }

  void recordHeartbeat({ApplierPhase? phase}) {
    state = state.copyWith(
      lastHeartbeat: DateTime.now(),
      phase: phase ?? state.phase,
    );
  }

  Future<void> startAutomation() async {
    LocalLogger.log('▶ Automation STARTED');
    state = state.copyWith(
      isAutomating: true,
      phase: ApplierPhase.searching,
      clearError: true,
    );

    if (state.isChromeMode) {
      try {
        await _chromeService.launchBrowser();
        state = state.copyWith(isChromeConnected: true);
        
        final profileData = await _service.getUserProfile();
        await _chromeService.startLinkedInAutomation(
          profile: profileData,
          jobPrefs: profileData, // Profile now contains job preferences directly
          searchUrls: state.searchUrls,
        );
      } catch (e) {
        setError('Chrome Bridge Error: $e');
        state = state.copyWith(isAutomating: false, isChromeConnected: false);
      }
    }
  }

  void pauseAutomation() {
    state = state.copyWith(
      isAutomating: false,
      phase: ApplierPhase.browsing,
    );
  }

  void stopAutomation() {
    LocalLogger.log('⏹ Automation STOPPED');
    state = state.copyWith(
      isAutomating: false,
      phase: ApplierPhase.loggedIn,
      clearCurrentJob: true,
    );
  }

  void confirmSubmit() {
    state = state.copyWith(phase: ApplierPhase.submitted);
  }

  // ── Job Context ───────────────────────────────────────────────

  void setCurrentJob(String title, String company, String url) {
    state = state.copyWith(
      currentJobTitle: title,
      currentCompany: company,
      currentUrl: url,
    );
  }

  // ── Application Logging ───────────────────────────────────────

  Future<void> logApplication({
    required String jobTitle,
    required String companyName,
    required String jobUrl,
    String status = 'applied',
    String? notes,
    int questionsAnswered = 0,
    int questionsManual = 0,
  }) async {
    try {
      await _service.logApplication(
        jobTitle: jobTitle,
        companyName: companyName,
        jobUrl: jobUrl,
        status: status,
        notes: notes,
        questionsAnswered: questionsAnswered,
        questionsManual: questionsManual,
      );

      // Refresh stats
      await loadStats();
      
      // Invalidate global dashboard to sync across all screens
      ref.invalidate(dashboardProvider);
    } catch (e) {
      debugPrint('Failed to log application: $e');
    }
  }

  // ── Stats & History ───────────────────────────────────────────

  Future<void> loadStats() async {
    state = state.copyWith(isLoadingStats: true);
    try {
      final stats = await _service.getStats();
      state = state.copyWith(
        todayApplied: stats['today_applied'] ?? 0,
        todayTotal: stats['today_total'] ?? 0,
        allTimeTotal: stats['all_time_total'] ?? 0,
        isLoadingStats: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingStats: false);
    }
  }

  Future<void> loadHistory() async {
    try {
      final result = await _service.getHistory();
      final apps = List<Map<String, dynamic>>.from(result['applications'] ?? []);
      state = state.copyWith(applicationHistory: apps);
    } catch (e) {
      debugPrint('Failed to load history: $e');
    }
  }

  // ── Error Handling ────────────────────────────────────────────

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void setError(String message) {
    LocalLogger.log('🚨 ERROR: $message');
    state = state.copyWith(
      errorMessage: message,
      phase: ApplierPhase.error,
    );
  }

  Future<void> reportFailure({
    required String message,
    String? screenshotBase64,
    String action = 'unknown',
    String? stackTrace,
  }) async {
    try {
      await _service.reportError(
        errorMessage: message,
        jobTitle: state.currentJobTitle,
        jobUrl: state.currentUrl,
        action: action,
        stackTrace: stackTrace,
        screenshotBase64: screenshotBase64,
        webviewState: {
          'phase': state.phase.name,
          'isLinkedInLoggedIn': state.isLinkedInLoggedIn,
          'isAutomating': state.isAutomating,
          'todayApplied': state.todayApplied,
        },
      );
    } catch (e) {
      debugPrint('Error reporting failure: $e');
    }
  }



  // ── Reset ─────────────────────────────────────────────────────

  void reset() {
    state = const ApplierState();
  }
}

/// Provider for the LinkedIn Auto Applier state.
final applierProvider = NotifierProvider<ApplierNotifier, ApplierState>(
  ApplierNotifier.new,
);
