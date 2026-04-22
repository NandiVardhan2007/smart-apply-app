/// Model representing the AI-generated LinkedIn optimization result.
///
/// Mirrors the backend response structure from the `/api/linkedin/optimize` endpoint.
/// Used to present scored categories, suggestions, and improvement plans in the UI.
class LinkedInOptimizationResult {
  final int overallScore;
  final String overallGrade;
  final String summary;
  final List<OptimizationCategory> categories;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<ImprovementAction> improvementPlan;

  const LinkedInOptimizationResult({
    this.overallScore = 0,
    this.overallGrade = 'N/A',
    this.summary = '',
    this.categories = const [],
    this.strengths = const [],
    this.weaknesses = const [],
    this.improvementPlan = const [],
  });

  factory LinkedInOptimizationResult.fromJson(Map<String, dynamic> json) {
    return LinkedInOptimizationResult(
      overallScore: _clamp(json['overall_score']),
      overallGrade: json['overall_grade']?.toString() ?? 'N/A',
      summary: json['summary']?.toString() ?? '',
      categories: _parseList<OptimizationCategory>(
        json['categories'],
        (e) => OptimizationCategory.fromJson(Map<String, dynamic>.from(e)),
      ),
      strengths: _parseStringList(json['strengths']),
      weaknesses: _parseStringList(json['weaknesses']),
      improvementPlan: _parseList<ImprovementAction>(
        json['improvement_plan'],
        (e) => ImprovementAction.fromJson(Map<String, dynamic>.from(e)),
      ),
    );
  }

  static int _clamp(dynamic val) {
    final v = int.tryParse(val?.toString() ?? '') ?? 0;
    return v.clamp(0, 100);
  }

  static List<T> _parseList<T>(dynamic val, T Function(dynamic) mapper) {
    if (val == null || val is! List) return [];
    return val.map(mapper).toList();
  }

  static List<String> _parseStringList(dynamic val) {
    if (val == null || val is! List) return [];
    return val.map((e) => e.toString()).toList();
  }
}

/// A single scored optimization category (e.g., "Headline Power", "Experience Impact").
class OptimizationCategory {
  final String name;
  final int score;
  final String grade;
  final String icon;
  final List<String> findings;
  final List<String> suggestions;

  const OptimizationCategory({
    this.name = '',
    this.score = 0,
    this.grade = '',
    this.icon = '',
    this.findings = const [],
    this.suggestions = const [],
  });

  factory OptimizationCategory.fromJson(Map<String, dynamic> json) {
    return OptimizationCategory(
      name: json['name']?.toString() ?? '',
      score: (json['score'] as num?)?.toInt().clamp(0, 100) ?? 0,
      grade: json['grade']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'info',
      findings: LinkedInOptimizationResult._parseStringList(json['findings']),
      suggestions:
          LinkedInOptimizationResult._parseStringList(json['suggestions']),
    );
  }
}

/// A single prioritized improvement action with expected impact.
class ImprovementAction {
  final String priority; // HIGH, MEDIUM, LOW
  final String action;
  final String impact;
  final String details;

  const ImprovementAction({
    this.priority = 'MEDIUM',
    this.action = '',
    this.impact = '',
    this.details = '',
  });

  factory ImprovementAction.fromJson(Map<String, dynamic> json) {
    return ImprovementAction(
      priority: json['priority']?.toString() ?? 'MEDIUM',
      action: json['action']?.toString() ?? '',
      impact: json['impact']?.toString() ?? '',
      details: json['details']?.toString() ?? '',
    );
  }
}
