import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../shared/widgets/glass_container.dart';
import 'models/linkedin_profile_model.dart';
import 'models/linkedin_optimization_result.dart';
import 'services/linkedin_webview_controller.dart';
import 'widgets/linkedin_intro_card.dart';
import 'widgets/optimization_result_view.dart';

/// The state machine driving the LinkedIn Profile Optimizer flow.
enum _ScreenPhase {
  intro,
  webview,
  analyzing,
  results,
  error,
}

class LinkedinOptimizingScreen extends StatefulWidget {
  const LinkedinOptimizingScreen({super.key});

  @override
  State<LinkedinOptimizingScreen> createState() =>
      _LinkedinOptimizingScreenState();
}

class _LinkedinOptimizingScreenState extends State<LinkedinOptimizingScreen>
    with TickerProviderStateMixin {
  // ─── State ───
  _ScreenPhase _phase = _ScreenPhase.intro;
  LinkedInProfileData? _profileData;
  LinkedInOptimizationResult? _result;

  // ─── WebView ───
  LinkedInWebViewController? _webViewController;
  LinkedInWebViewState _webViewState = LinkedInWebViewState.idle;
  String _webViewUrl = '';

  // ─── Subscriptions ───
  StreamSubscription<LinkedInWebViewState>? _stateSub;
  StreamSubscription<String>? _urlSub;
  StreamSubscription<String>? _errorSub;

  // ─── Analyzing animation ───
  late AnimationController _pulseController;
  int _analyzingStep = 0;
  Timer? _analyzingTimer;

  static const _analyzingSteps = [
    'Preparing profile data...',
    'Analyzing headline impact...',
    'Evaluating about section...',
    'Reviewing experience entries...',
    'Checking education & certifications...',
    'Assessing skills strategy...',
    'Analyzing visual branding...',
    'Measuring profile completeness...',
    'Optimizing keyword density...',
    'Generating improvement plan...',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _analyzingTimer?.cancel();
    _stateSub?.cancel();
    _urlSub?.cancel();
    _errorSub?.cancel();
    _webViewController?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────

  void _startWebView() {
    _webViewController = LinkedInWebViewController();
    _stateSub = _webViewController!.stateStream.listen(_onWebViewStateChanged);
    _urlSub = _webViewController!.urlStream.listen((url) {
      if (mounted) setState(() => _webViewUrl = url);
    });
    _errorSub = _webViewController!.errorStream.listen((err) {
      if (mounted) {
        _showSnackBar(err, isError: true);
      }
    });
    _webViewController!.loadLoginPage();
    setState(() {
      _phase = _ScreenPhase.webview;
    });
  }

  void _onWebViewStateChanged(LinkedInWebViewState state) {
    if (!mounted) return;
    setState(() => _webViewState = state);

    if (state == LinkedInWebViewState.loggedIn) {
      // Show banner to navigate to profile
      _showGoToProfileBanner();
    } else if (state == LinkedInWebViewState.profilePageReady) {
      // Manual extraction only from now on
    }
  }

  void _showGoToProfileBanner() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Logged in! Tap to go to your profile.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0A66C2),
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'Go to Profile',
          textColor: Colors.white,
          onPressed: () {
            _webViewController?.navigateToMyProfile();
          },
        ),
      ),
    );
  }

  Future<void> _extractProfile() async {
    if (_webViewController == null) return;

    final data = await _webViewController!.extractProfileData();
    if (data != null && data.isViable && mounted) {
      setState(() => _profileData = data);
      _startAnalysis();
    } else if (mounted) {
      _showSnackBar(
        'Could not extract enough profile data. Make sure your full profile page is loaded.',
        isError: true,
      );
    }
  }

  Future<void> _startAnalysis() async {
    if (_profileData == null) return;

    setState(() {
      _phase = _ScreenPhase.analyzing;
      _analyzingStep = 0;
    });

    // Cleanup WebView resources
    _stateSub?.cancel();
    _urlSub?.cancel();
    _errorSub?.cancel();
    _webViewController?.dispose();
    _webViewController = null;

    // Start step animation
    _analyzingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        if (_analyzingStep < _analyzingSteps.length - 1) {
          setState(() => _analyzingStep++);
        } else if (_analyzingStep == _analyzingSteps.length - 1) {
          // Stay on last step but maybe update status to "Still working" after 15s total
          if (timer.tick > 15) {
             setState(() => _analyzingStep = _analyzingSteps.length); // Trigger a special 'Finalizing' state
          }
        }
      }
    });

    try {
      final response = await apiClient.post(
        '/api/linkedin/optimize',
        data: {'profile_data': _profileData!.toJson()},
      );

      _analyzingTimer?.cancel();

      if (mounted) {
        final result =
            LinkedInOptimizationResult.fromJson(Map<String, dynamic>.from(response.data));
        setState(() {
          _result = result;
          _phase = _ScreenPhase.results;
        });
      }
    } catch (e) {
      _analyzingTimer?.cancel();
      if (mounted) {
        setState(() {
          _phase = _ScreenPhase.error;
        });
        _showSnackBar('Analysis failed: Check details below', isError: true);
      }
    }
}

  void _resetToIntro() {
    _stateSub?.cancel();
    _urlSub?.cancel();
    _errorSub?.cancel();
    _webViewController?.dispose();
    _webViewController = null;
    _analyzingTimer?.cancel();

    setState(() {
      _phase = _ScreenPhase.intro;
      _profileData = null;
      _result = null;
      _webViewState = LinkedInWebViewState.idle;
      _webViewUrl = '';
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFFF6B6B) : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase == _ScreenPhase.intro,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_phase == _ScreenPhase.webview) {
          final wentBack = await _webViewController?.goBack() ?? false;
          if (!wentBack && mounted) {
            _resetToIntro();
          }
        } else if (_phase == _ScreenPhase.results) {
          _resetToIntro();
        } else if (_phase == _ScreenPhase.analyzing) {
          // Don't allow back during analysis
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: switch (_phase) {
              _ScreenPhase.intro => _buildIntroView(),
              _ScreenPhase.webview => _buildWebViewView(),
              _ScreenPhase.analyzing => _buildAnalyzingView(),
              _ScreenPhase.results => _buildResultsView(),
              _ScreenPhase.error => _buildErrorView(),
            },
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // 1. INTRO VIEW
  // ═══════════════════════════════════════════════

  Widget _buildIntroView() {
    return Column(
      key: const ValueKey('intro'),
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile Optimizer',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      'Powered by AI',
                      style: TextStyle(
                        color: AppColors.onSurface.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
        // Body
        Expanded(
          child: LinkedInIntroCard(onConnect: _startWebView),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════
  // 2. WEBVIEW VIEW
  // ═══════════════════════════════════════════════

  Widget _buildWebViewView() {
    return Column(
      key: const ValueKey('webview'),
      children: [
        // Top bar with navigation controls
        _buildWebViewToolbar(),
        // Status indicator
        _buildWebViewStatusBar(),
        // WebView
        Expanded(
          child: _webViewController != null
              ? WebViewWidget(controller: _webViewController!.controller)
              : const Center(child: CircularProgressIndicator()),
        ),
        // Bottom action bar
        _buildWebViewBottomBar(),
      ],
    );
  }

  Widget _buildWebViewToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: _resetToIntro,
            icon: const Icon(Icons.close, size: 22),
            tooltip: 'Close',
          ),
          IconButton(
            onPressed: () => _webViewController?.goBack(),
            icon: const Icon(Icons.arrow_back, size: 22),
            tooltip: 'Back',
          ),
          IconButton(
            onPressed: () => _webViewController?.reload(),
            icon: const Icon(Icons.refresh, size: 22),
            tooltip: 'Reload',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    _webViewUrl.contains('https')
                        ? Icons.lock_outline
                        : Icons.language,
                    size: 14,
                    color: AppColors.success.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _webViewUrl.isNotEmpty
                          ? Uri.tryParse(_webViewUrl)?.host ?? _webViewUrl
                          : 'Loading...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurface.withValues(alpha: 0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildWebViewStatusBar() {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (_webViewState) {
      case LinkedInWebViewState.loading:
        statusText = 'Loading...';
        statusColor = AppColors.onSurface;
        statusIcon = Icons.hourglass_top;
        break;
      case LinkedInWebViewState.loginPage:
        statusText = 'Please log in to your LinkedIn account';
        statusColor = const Color(0xFF0A66C2);
        statusIcon = Icons.login;
        break;
      case LinkedInWebViewState.loggedIn:
        statusText = 'Logged in! Navigate to your profile';
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        break;
      case LinkedInWebViewState.navigatingToProfile:
        statusText = 'Going to your profile...';
        statusColor = AppColors.primary;
        statusIcon = Icons.person;
        break;
      case LinkedInWebViewState.profilePageReady:
        statusText = 'Profile loaded — extracting data...';
        statusColor = AppColors.tertiary;
        statusIcon = Icons.auto_awesome;
        break;
      case LinkedInWebViewState.extracting:
        statusText = 'Extracting profile data...';
        statusColor = AppColors.secondary;
        statusIcon = Icons.downloading;
        break;
      case LinkedInWebViewState.extracted:
        statusText = 'Profile data captured!';
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        break;
      case LinkedInWebViewState.error:
        statusText = 'Something went wrong';
        statusColor = const Color(0xFFFF6B6B);
        statusIcon = Icons.error_outline;
        break;
      default:
        statusText = 'Initializing...';
        statusColor = AppColors.onSurface;
        statusIcon = Icons.hourglass_empty;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(
            color: statusColor.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 13,
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (_webViewState == LinkedInWebViewState.loading)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(statusColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWebViewBottomBar() {
    final showExtractButton =
        _webViewState == LinkedInWebViewState.profilePageReady ||
        _webViewState == LinkedInWebViewState.loggedIn ||
        _webViewState == LinkedInWebViewState.error;

    final showGoToProfile =
        _webViewState == LinkedInWebViewState.loggedIn;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(
            color: AppColors.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          if (showGoToProfile)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _webViewController?.navigateToMyProfile(),
                icon: const Icon(Icons.person, size: 20),
                label: const Text('Go to My Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A66C2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          if (showGoToProfile && showExtractButton) const SizedBox(width: 10),
          if (showExtractButton &&
              _webViewState == LinkedInWebViewState.profilePageReady)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _extractProfile,
                icon: const Icon(Icons.download_done, size: 20),
                label: const Text('Extract & Analyze'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // 3. ANALYZING VIEW
  // ═══════════════════════════════════════════════

  Widget _buildAnalyzingView() {
    final progress = (_analyzingStep + 1) / _analyzingSteps.length;

    return Center(
      key: const ValueKey('analyzing'),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated LinkedIn icon
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.12),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF0A66C2).withValues(alpha: 0.25),
                          const Color(0xFF0A66C2).withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.auto_awesome,
                          size: 52, color: Color(0xFF0A66C2)),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),

            // Profile summary
            if (_profileData != null) ...[
              GlassContainer(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _profileData!.fullName.isNotEmpty
                            ? _profileData!.fullName
                            : 'LinkedIn Profile',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
            ],

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.surfaceHigh,
                valueColor:
                    const AlwaysStoppedAnimation(Color(0xFF0A66C2)),
              ),
            ),
            const SizedBox(height: 20),

            // Status text
            Text(
              _analyzingStep < _analyzingSteps.length 
                  ? _analyzingSteps[_analyzingStep]
                  : 'AI is finalizing your report...',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (_analyzingStep >= _analyzingSteps.length)
              Text(
                'Complex profiles can take up to 30 seconds to optimize, Sir.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurface.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(),
            const SizedBox(height: 8),
            Text(
              _analyzingStep < _analyzingSteps.length
                  ? 'Step ${_analyzingStep + 1} of ${_analyzingSteps.length}'
                  : 'Almost there...',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView() {
    if (_result == null) return const SizedBox.shrink();

    return OptimizationResultView(
      key: const ValueKey('results'),
      result: _result!,
      onNewScan: _resetToIntro,
    );
  }

  // ═══════════════════════════════════════════════
  // 5. ERROR VIEW
  // ═══════════════════════════════════════════════

  Widget _buildErrorView() {
    return Center(
      key: const ValueKey('error'),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 40,
                color: Color(0xFFFF6B6B),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Analysis Failed',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'The AI was unable to process your profile data at this time. This is usually due to a transient error or malformed response.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startAnalysis,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _resetToIntro,
              child: Text(
                'Cancel & Start Over',
                style: TextStyle(
                  color: AppColors.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
