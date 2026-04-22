/// Strongly-typed model representing LinkedIn profile data extracted from the WebView.
///
/// This model captures all relevant profile fields needed for AI-driven
/// optimization analysis. It is populated by JavaScript extraction and
/// serialized to JSON for the backend API.
class LinkedInProfileData {
  final String fullName;
  final String headline;
  final String about;
  final String location;
  final String currentRole;
  final List<ExperienceEntry> experience;
  final List<EducationEntry> education;
  final List<String> skills;
  final List<String> certifications;
  final bool hasProfilePhoto;
  final bool hasBannerPhoto;
  final String profileUrl;
  final String connectionsCount;
  final Map<String, dynamic> rawExtras;

  const LinkedInProfileData({
    this.fullName = '',
    this.headline = '',
    this.about = '',
    this.location = '',
    this.currentRole = '',
    this.experience = const [],
    this.education = const [],
    this.skills = const [],
    this.certifications = const [],
    this.hasProfilePhoto = false,
    this.hasBannerPhoto = false,
    this.profileUrl = '',
    this.connectionsCount = '',
    this.rawExtras = const {},
  });

  /// Whether the extracted data has enough content for meaningful analysis.
  bool get isViable =>
      fullName.isNotEmpty || headline.isNotEmpty || about.isNotEmpty;

  /// Human-readable summary for UI display.
  String get briefSummary {
    final parts = <String>[];
    if (fullName.isNotEmpty) parts.add(fullName);
    if (headline.isNotEmpty) parts.add(headline);
    if (experience.isNotEmpty) {
      parts.add('${experience.length} experience entries');
    }
    if (skills.isNotEmpty) parts.add('${skills.length} skills');
    return parts.join(' · ');
  }

  /// Convert to JSON for the backend API.
  Map<String, dynamic> toJson() => {
        'full_name': fullName,
        'headline': headline,
        'about': about,
        'location': location,
        'current_role': currentRole,
        'experience': experience.map((e) => e.toJson()).toList(),
        'education': education.map((e) => e.toJson()).toList(),
        'skills': skills,
        'certifications': certifications,
        'has_profile_photo': hasProfilePhoto,
        'has_banner_photo': hasBannerPhoto,
        'profile_url': profileUrl,
        'connections_count': connectionsCount,
        'raw_extras': rawExtras,
      };

  /// Create from the raw map returned by JavaScript extraction.
  factory LinkedInProfileData.fromExtractedMap(Map<String, dynamic> map) {
    return LinkedInProfileData(
      fullName: _str(map['fullName'] ?? map['full_name']),
      headline: _str(map['headline']),
      about: _str(map['about']),
      location: _str(map['location']),
      currentRole: _str(map['currentRole'] ?? map['current_role']),
      experience: _parseList<ExperienceEntry>(
        map['experience'],
        (e) => ExperienceEntry.fromMap(Map<String, dynamic>.from(e)),
      ),
      education: _parseList<EducationEntry>(
        map['education'],
        (e) => EducationEntry.fromMap(Map<String, dynamic>.from(e)),
      ),
      skills: _parseStringList(map['skills']),
      certifications: _parseStringList(map['certifications']),
      hasProfilePhoto: map['hasProfilePhoto'] == true ||
          map['has_profile_photo'] == true,
      hasBannerPhoto: map['hasBannerPhoto'] == true ||
          map['has_banner_photo'] == true,
      profileUrl: _str(map['profileUrl'] ?? map['profile_url']),
      connectionsCount:
          _str(map['connectionsCount'] ?? map['connections_count']),
      rawExtras: Map<String, dynamic>.from(map['rawExtras'] ?? map['raw_extras'] ?? {}),
    );
  }

  static String _str(dynamic val) => val?.toString().trim() ?? '';

  static List<T> _parseList<T>(dynamic val, T Function(dynamic) mapper) {
    if (val == null || val is! List) return [];
    return val.map(mapper).toList();
  }

  static List<String> _parseStringList(dynamic val) {
    if (val == null || val is! List) return [];
    return val.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
  }
}

/// A single work experience entry.
class ExperienceEntry {
  final String title;
  final String company;
  final String dateRange;
  final String description;
  final String location;

  const ExperienceEntry({
    this.title = '',
    this.company = '',
    this.dateRange = '',
    this.description = '',
    this.location = '',
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'company': company,
        'date_range': dateRange,
        'description': description,
        'location': location,
      };

  factory ExperienceEntry.fromMap(Map<String, dynamic> map) => ExperienceEntry(
        title: map['title']?.toString() ?? '',
        company: map['company']?.toString() ?? '',
        dateRange: (map['dateRange'] ?? map['date_range'])?.toString() ?? '',
        description: map['description']?.toString() ?? '',
        location: map['location']?.toString() ?? '',
      );
}

/// A single education entry.
class EducationEntry {
  final String institution;
  final String degree;
  final String fieldOfStudy;
  final String dateRange;
  final String description;

  const EducationEntry({
    this.institution = '',
    this.degree = '',
    this.fieldOfStudy = '',
    this.dateRange = '',
    this.description = '',
  });

  Map<String, dynamic> toJson() => {
        'institution': institution,
        'degree': degree,
        'field_of_study': fieldOfStudy,
        'date_range': dateRange,
        'description': description,
      };

  factory EducationEntry.fromMap(Map<String, dynamic> map) => EducationEntry(
        institution: map['institution']?.toString() ?? '',
        degree: map['degree']?.toString() ?? '',
        fieldOfStudy:
            (map['fieldOfStudy'] ?? map['field_of_study'])?.toString() ?? '',
        dateRange: (map['dateRange'] ?? map['date_range'])?.toString() ?? '',
        description: map['description']?.toString() ?? '',
      );
}
