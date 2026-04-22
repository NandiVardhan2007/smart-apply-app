class ApiConstants {
  static const String baseUrl = 'https://smart-apply-ai-by6m.onrender.com';
  static const String apiBase = '$baseUrl/api';

  // Auth
  static const String login = '$apiBase/auth/login';
  static const String register = '$apiBase/auth/register';
  static const String verifyOtp = '$apiBase/auth/verify-otp';
  static const String requestOtp = '$apiBase/auth/request-otp';
  static const String forgotPassword = '$apiBase/auth/forgot-password';
  static const String resetPassword = '$apiBase/auth/reset-password';

  // User
  static const String profile = '$apiBase/user/profile';
  static const String uploadAvatar = '$apiBase/user/upload-avatar';
  static const String uploadResume = '$apiBase/user/upload-resume';
  static const String parseResume = '$apiBase/user/parse-resume';
  static const String generateAutomationTerms = '$apiBase/user/generate-automation-terms';
  static String deleteResume(String id) => '$apiBase/user/resumes/$id';
  static String setDefaultResume(String id) => '$apiBase/user/resumes/$id/set-default';

  // ATS Analysis
  static const String atsScan = '$apiBase/ats/scan';
  static const String atsHistory = '$apiBase/ats/history';
  static String atsScanDetail(String scanId) => '$apiBase/ats/scan/$scanId';

  // LinkedIn Optimizer
  static const String linkedinOptimize = '$apiBase/linkedin/optimize';
  static const String linkedinHistory = '$apiBase/linkedin/history';
  static String linkedinOptimizationDetail(String id) =>
      '$apiBase/linkedin/optimization/$id';

  // LinkedIn Auto Applier
  static const String applier = '$apiBase/linkedin-applier';
  static const String applierSearchTerms = '$applier/search-terms';
  static const String applierAnswerQuestion = '$applier/answer-question';
  static const String applierSaveAnswer = '$applier/save-answer';
  static const String applierLogApplication = '$applier/log-application';
  static const String applierHistory = '$applier/history';
  static const String applierStats = '$applier/stats';
  static const String applierSavedAnswers = '$applier/saved-answers';
  static const String applierEngineLatest = '$applier/engine/latest';
  static const String applierEngineHeal = '$applier/engine/heal';

  // Resume Tailoring
  static const String resumeTailorGenerate = '$apiBase/resume-tailor/generate';
  static const String resumeTailorScrapeJob = '$apiBase/resume-tailor/scrape-job';
  static const String resumeTailorHistory = '$apiBase/resume-tailor/history';
  static String resumeTailorDetail(String id) => '$apiBase/resume-tailor/$id';
  static String resumeTailorPdf(String id) => '$apiBase/resume-tailor/$id/pdf';

  // Email Agent
  static const String emailAgentScan = '$apiBase/email-agent/scan';
  static const String emailAgentDraftReply = '$apiBase/email-agent/draft-reply';
  static const String emailAgentSendReply = '$apiBase/email-agent/send-reply';
  static const String emailAuthUrl = '$apiBase/email-auth/url';
  static const String emailAuthCallback = '$apiBase/email-auth/callback';
}
