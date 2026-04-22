import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/linkedin_profile_model.dart';

/// Possible states of the LinkedIn WebView flow.
enum LinkedInWebViewState {
  idle,
  loading,
  loginPage,
  loggedIn,
  navigatingToProfile,
  profilePageReady,
  extracting,
  extracted,
  error,
}

/// Encapsulates all WebView logic for the LinkedIn Profile Optimizer.
///
/// - Configures the WebViewController with JavaScript enabled
/// - Loads the LinkedIn login page
/// - Monitors URL changes to detect login completion and profile page arrival
/// - Runs JavaScript extraction to pull profile data from the DOM
/// - Exposes a state stream so the UI can react to changes
class LinkedInWebViewController {
  late final WebViewController controller;

  final _stateController =
      StreamController<LinkedInWebViewState>.broadcast();
  final _profileController =
      StreamController<LinkedInProfileData>.broadcast();
  final _urlController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<LinkedInWebViewState> get stateStream => _stateController.stream;
  Stream<LinkedInProfileData> get profileStream => _profileController.stream;
  Stream<String> get urlStream => _urlController.stream;
  Stream<String> get errorStream => _errorController.stream;

  LinkedInWebViewState _currentState = LinkedInWebViewState.idle;
  LinkedInWebViewState get currentState => _currentState;

  String _currentUrl = '';
  String get currentUrl => _currentUrl;

  bool _isDisposed = false;

  LinkedInWebViewController() {
    _initController();
  }

  void _initController() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: _onPageStarted,
          onPageFinished: _onPageFinished,
          onNavigationRequest: _onNavigationRequest,
          onWebResourceError: _onWebResourceError,
        ),
      );
  }

  /// Load the LinkedIn login page to start the flow.
  void loadLoginPage() {
    _setState(LinkedInWebViewState.loading);
    controller.loadRequest(Uri.parse('https://www.linkedin.com/login'));
  }

  /// Navigate WebView to the user's own profile.
  void navigateToMyProfile() {
    _setState(LinkedInWebViewState.navigatingToProfile);
    controller.loadRequest(Uri.parse('https://www.linkedin.com/in/me/'));
  }

  /// Go back in the WebView if possible.
  Future<bool> goBack() async {
    if (await controller.canGoBack()) {
      await controller.goBack();
      return true;
    }
    return false;
  }

  /// Reload the current page.
  Future<void> reload() async {
    await controller.reload();
  }

  /// Manually trigger profile data extraction.
  Future<LinkedInProfileData?> extractProfileData() async {
    _setState(LinkedInWebViewState.extracting);
    try {
      final result =
          await controller.runJavaScriptReturningResult(_extractionScript);

      String jsonStr;
      if (result is String) {
        // Remove surrounding quotes if the WebView stringifies the result
        jsonStr = result;
        if (jsonStr.startsWith('"') && jsonStr.endsWith('"')) {
          jsonStr = jsonStr.substring(1, jsonStr.length - 1);
          // Unescape
          jsonStr = jsonStr
              .replaceAll(r'\"', '"')
              .replaceAll(r'\\n', '\n')
              .replaceAll(r'\\t', '\t');
        }
      } else {
        jsonStr = result.toString();
      }

      final Map<String, dynamic> extracted = jsonDecode(jsonStr);
      final profileData = LinkedInProfileData.fromExtractedMap(extracted);

      // Attach the current URL as the profile URL
      final updatedData = LinkedInProfileData(
        fullName: profileData.fullName,
        headline: profileData.headline,
        about: profileData.about,
        location: profileData.location,
        currentRole: profileData.currentRole,
        experience: profileData.experience,
        education: profileData.education,
        skills: profileData.skills,
        certifications: profileData.certifications,
        hasProfilePhoto: profileData.hasProfilePhoto,
        hasBannerPhoto: profileData.hasBannerPhoto,
        profileUrl:
            profileData.profileUrl.isNotEmpty ? profileData.profileUrl : _currentUrl,
        connectionsCount: profileData.connectionsCount,
        rawExtras: profileData.rawExtras,
      );

      if (!_isDisposed) {
        _profileController.add(updatedData);
        _setState(LinkedInWebViewState.extracted);
      }
      return updatedData;
    } catch (e) {
      debugPrint('[LinkedIn Extractor] Extraction error: $e');
      if (!_isDisposed) {
        _errorController.add('Failed to extract profile data: $e');
        _setState(LinkedInWebViewState.error);
      }
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // NAVIGATION CALLBACKS
  // ─────────────────────────────────────────────

  void _onPageStarted(String url) {
    _currentUrl = url;
    if (!_isDisposed) {
      _urlController.add(url);
      _setState(LinkedInWebViewState.loading);
    }
  }

  void _onPageFinished(String url) {
    _currentUrl = url;
    if (_isDisposed) return;

    _urlController.add(url);

    if (_isLoginPage(url)) {
      _setState(LinkedInWebViewState.loginPage);
    } else if (_isProfilePage(url)) {
      _setState(LinkedInWebViewState.profilePageReady);
    } else if (_isLoggedIn(url)) {
      _setState(LinkedInWebViewState.loggedIn);
    }
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final url = request.url;
    // Block external links that would leave LinkedIn
    if (!url.contains('linkedin.com') &&
        !url.contains('licdn.com') &&
        !url.contains('microsoft.com') &&
        !url.contains('microsoftonline.com') &&
        !url.startsWith('about:') &&
        !url.startsWith('data:')) {
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  void _onWebResourceError(WebResourceError error) {
    debugPrint('[LinkedIn WebView] Resource error: ${error.description}');
    // Only report critical errors, not sub-resource failures
    if (error.isForMainFrame ?? false) {
      if (!_isDisposed) {
        _errorController
            .add('Page failed to load: ${error.description}');
        _setState(LinkedInWebViewState.error);
      }
    }
  }

  // ─────────────────────────────────────────────
  // URL DETECTION HELPERS
  // ─────────────────────────────────────────────

  bool _isLoginPage(String url) {
    return url.contains('linkedin.com/login') ||
        url.contains('linkedin.com/checkpoint') ||
        url.contains('linkedin.com/uas');
  }

  bool _isLoggedIn(String url) {
    return url.contains('linkedin.com/feed') ||
        url.contains('linkedin.com/mynetwork') ||
        url.contains('linkedin.com/messaging') ||
        url.contains('linkedin.com/notifications') ||
        url.contains('linkedin.com/jobs');
  }

  bool _isProfilePage(String url) {
    // Matches /in/me/ or /in/{username}
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final path = uri.path.toLowerCase();
    return RegExp(r'^/in/[^/]+/?$').hasMatch(path);
  }

  void _setState(LinkedInWebViewState state) {
    _currentState = state;
    if (!_isDisposed) {
      _stateController.add(state);
    }
  }

  /// Clean up resources.
  void dispose() {
    _isDisposed = true;
    _stateController.close();
    _profileController.close();
    _urlController.close();
    _errorController.close();
  }

  // ─────────────────────────────────────────────
  // JAVASCRIPT EXTRACTION SCRIPT
  // ─────────────────────────────────────────────

  /// JavaScript that runs inside the LinkedIn profile page to extract data.
  ///
  /// Uses multiple fallback selectors to handle LinkedIn's evolving DOM.
  /// Returns a JSON string with all extracted profile fields.
  static const String _extractionScript = '''
(function() {
  function q(selectors) {
    if (typeof selectors === 'string') selectors = [selectors];
    for (var i = 0; i < selectors.length; i++) {
      var el = document.querySelector(selectors[i]);
      if (el && el.innerText && el.innerText.trim().length > 0) {
        return el.innerText.trim();
      }
    }
    return '';
  }

  function qAll(selectors) {
    if (typeof selectors === 'string') selectors = [selectors];
    for (var i = 0; i < selectors.length; i++) {
      var els = document.querySelectorAll(selectors[i]);
      if (els.length > 0) return Array.from(els);
    }
    return [];
  }

  // --- Name ---
  var fullName = q([
    'h1.text-heading-xlarge',
    'h1.inline',
    '.pv-text-details__left-panel h1',
    '.profile-topcard-person-entity__name',
    'h1'
  ]);

  // --- Headline ---
  var headline = q([
    'div.text-body-medium.break-words',
    '.pv-text-details__left-panel .text-body-medium',
    '.profile-topcard__summary-position',
    'h2.mt1'
  ]);

  // --- Location ---
  var location = q([
    'span.text-body-small.inline',
    '.pv-text-details__left-panel span.text-body-small',
    '.profile-topcard__location-data'
  ]);

  // --- Connections ---
  var connectionsCount = q([
    'span.t-bold[tabindex] + span',
    '.pv-top-card--list.pv-top-card--list-bullet li:last-child span',
    'a[href*="connections"] span.t-bold'
  ]);
  if (!connectionsCount) {
    var connEl = document.querySelector('a[href*="connections"]');
    if (connEl) connectionsCount = connEl.innerText.trim();
  }

  // --- About ---
  var about = '';
  var aboutSection = document.querySelector('#about');
  if (aboutSection) {
    var aboutParent = aboutSection.closest('section');
    if (aboutParent) {
      var spans = aboutParent.querySelectorAll('span[aria-hidden="true"]');
      for (var s = 0; s < spans.length; s++) {
        var txt = spans[s].innerText.trim();
        if (txt.length > 30) { about = txt; break; }
      }
      if (!about) {
        var divs = aboutParent.querySelectorAll('.display-flex span');
        for (var d = 0; d < divs.length; d++) {
          var txt = divs[d].innerText.trim();
          if (txt.length > 30) { about = txt; break; }
        }
      }
    }
  }

  // --- Experience ---
  var experience = [];
  var expSection = document.querySelector('#experience');
  if (expSection) {
    var expParent = expSection.closest('section');
    if (expParent) {
      var items = expParent.querySelectorAll('li.artdeco-list__item');
      if (items.length === 0) items = expParent.querySelectorAll('ul > li');
      items.forEach(function(item) {
        var title = '';
        var company = '';
        var dateRange = '';
        var description = '';
        var loc = '';

        var spans = item.querySelectorAll('span[aria-hidden="true"]');
        if (spans.length >= 1) title = spans[0].innerText.trim();
        if (spans.length >= 2) company = spans[1].innerText.trim();
        if (spans.length >= 3) dateRange = spans[2].innerText.trim();
        if (spans.length >= 4) loc = spans[3].innerText.trim();

        var descEl = item.querySelector('.pv-shared-text-with-see-more span[aria-hidden="true"]');
        if (descEl) description = descEl.innerText.trim();

        if (title || company) {
          experience.push({
            title: title,
            company: company,
            dateRange: dateRange,
            description: description,
            location: loc
          });
        }
      });
    }
  }

  // --- Education ---
  var education = [];
  var eduSection = document.querySelector('#education');
  if (eduSection) {
    var eduParent = eduSection.closest('section');
    if (eduParent) {
      var items = eduParent.querySelectorAll('li.artdeco-list__item');
      if (items.length === 0) items = eduParent.querySelectorAll('ul > li');
      items.forEach(function(item) {
        var institution = '';
        var degree = '';
        var dateRange = '';

        var spans = item.querySelectorAll('span[aria-hidden="true"]');
        if (spans.length >= 1) institution = spans[0].innerText.trim();
        if (spans.length >= 2) degree = spans[1].innerText.trim();
        if (spans.length >= 3) dateRange = spans[2].innerText.trim();

        if (institution) {
          education.push({
            institution: institution,
            degree: degree,
            fieldOfStudy: '',
            dateRange: dateRange,
            description: ''
          });
        }
      });
    }
  }

  // --- Skills ---
  var skills = [];
  var skillSection = document.querySelector('#skills');
  if (skillSection) {
    var skillParent = skillSection.closest('section');
    if (skillParent) {
      var skillSpans = skillParent.querySelectorAll('li span[aria-hidden="true"]');
      skillSpans.forEach(function(s) {
        var txt = s.innerText.trim();
        // Filter out noise — skills are typically short
        if (txt.length > 0 && txt.length < 60 && !txt.includes('·') && !txt.includes('endorsement')) {
          skills.push(txt);
        }
      });
    }
  }

  // --- Certifications ---
  var certifications = [];
  var certSection = document.querySelector('#licenses_and_certifications') ||
                    document.querySelector('#certifications');
  if (certSection) {
    var certParent = certSection.closest('section');
    if (certParent) {
      var certSpans = certParent.querySelectorAll('li span[aria-hidden="true"]');
      certSpans.forEach(function(s) {
        var txt = s.innerText.trim();
        if (txt.length > 2 && txt.length < 120) {
          certifications.push(txt);
        }
      });
    }
  }

  // --- Profile Photo ---
  var hasProfilePhoto = false;
  var photoSelectors = [
    'img.pv-top-card-profile-picture__image',
    'img.profile-photo-edit__preview',
    'img.profile-topcard__photo',
    '.pv-top-card__photo img',
    '.profile-photo img'
  ];
  for (var p = 0; p < photoSelectors.length; p++) {
    var photoEl = document.querySelector(photoSelectors[p]);
    if (photoEl && photoEl.src && !photoEl.src.includes('ghost') && !photoEl.src.includes('data:image/gif')) {
      hasProfilePhoto = true;
      break;
    }
  }

  // --- Banner ---
  var hasBannerPhoto = false;
  var bannerSelectors = [
    '.profile-background-image img',
    'img[data-test-id*="background"]',
    '.cover-img__image',
    '.profile-background-image--loading + img'
  ];
  for (var b = 0; b < bannerSelectors.length; b++) {
    var bannerEl = document.querySelector(bannerSelectors[b]);
    if (bannerEl && bannerEl.src && !bannerEl.src.includes('default')) {
      hasBannerPhoto = true;
      break;
    }
  }

  // --- Current Role (first experience title) ---
  var currentRole = (experience.length > 0) ? experience[0].title : '';

  var result = {
    fullName: fullName,
    headline: headline,
    about: about,
    location: location,
    currentRole: currentRole,
    experience: experience,
    education: education,
    skills: skills,
    certifications: certifications,
    hasProfilePhoto: hasProfilePhoto,
    hasBannerPhoto: hasBannerPhoto,
    profileUrl: window.location.href,
    connectionsCount: connectionsCount,
    rawExtras: {}
  };

  return JSON.stringify(result);
})();
''';
}
