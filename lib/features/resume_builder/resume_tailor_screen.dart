import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/glass_container.dart';
import '../../shared/widgets/animated_ambient_background.dart';
import '../../core/utils/responsive_utils.dart';


class ResumeTailorScreen extends ConsumerStatefulWidget {
  const ResumeTailorScreen({super.key});

  @override
  ConsumerState<ResumeTailorScreen> createState() => _ResumeTailorScreenState();
}

class _ResumeTailorScreenState extends ConsumerState<ResumeTailorScreen>
    with SingleTickerProviderStateMixin {
  // Step management
  int _currentStep = 0; // 0=input, 1=analysis, 2=result

  // Input controllers
  final _urlController = TextEditingController();
  final _jdController = TextEditingController();
  int _inputTab = 0; // 0=URL, 1=JD
  String _styleHint = 'classic';

  // State
  bool _isScraping = false;
  bool _isGenerating = false;
  String? _errorMessage;

  // Scraped data
  Map<String, dynamic>? _scrapedJob;

  // Generation result
  Map<String, dynamic>? _result;

  // History
  List<dynamic> _history = [];
  bool _isLoadingHistory = true;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadHistory();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _jdController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ─── API Methods ────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    try {
      final res = await apiClient.get(ApiConstants.resumeTailorHistory);
      if (mounted) {
        setState(() {
          _history = res.data['tailored_resumes'] ?? [];
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _scrapeUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      setState(() => _errorMessage = 'Please enter a valid URL starting with http:// or https://');
      return;
    }

    setState(() {
      _isScraping = true;
      _errorMessage = null;
    });

    try {
      final res = await apiClient.post(
        ApiConstants.resumeTailorScrapeJob,
        data: {'url': url},
      );
      if (mounted) {
        setState(() {
          _scrapedJob = res.data;
          _jdController.text = res.data['description'] ?? '';
          _isScraping = false;
        });
        _showSnackBar('Job description extracted successfully!', isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScraping = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _generateResume() async {
    final jd = _jdController.text.trim();
    final url = _urlController.text.trim();

    if (jd.isEmpty && url.isEmpty) {
      setState(() => _errorMessage = 'Please provide a job description or URL.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _currentStep = 1; // Show analysis/loading step
    });

    try {
      final res = await apiClient.post(
        ApiConstants.resumeTailorGenerate,
        data: {
          'job_description': jd.isNotEmpty ? jd : null,
          'job_url': url.isNotEmpty ? url : null,
          'style_hint': _styleHint,
        },
      );
      if (mounted) {
        setState(() {
          _result = res.data;
          _isGenerating = false;
          _currentStep = 2; // Show result
        });
        _loadHistory(); // Refresh history
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _currentStep = 0; // Back to input
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _loadTailoredResume(String id) async {
    setState(() {
      _isGenerating = true;
      _currentStep = 1;
    });

    try {
      final res = await apiClient.get(ApiConstants.resumeTailorDetail(id));
      if (mounted) {
        setState(() {
          _result = res.data;
          _isGenerating = false;
          _currentStep = 2;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _currentStep = 0;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _copyToClipboard() {
    final latex = _result?['latex_code'] ?? '';
    Clipboard.setData(ClipboardData(text: latex));
    _showSnackBar('LaTeX copied to clipboard!', isSuccess: true);
  }

  void _viewPdfPreview() {
    if (_result == null || _result!['id'] == null) return;
    context.push('/pdf-preview', extra: {
      'resumeId': _result!['id'],
      'title': 'Tailored Resume - ${_result!['job_title']}',
    });
  }

  void _resetToInput() {
    setState(() {
      _currentStep = 0;
      _result = null;
      _errorMessage = null;
    });
  }

  void _showSnackBar(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Resume Tailor', style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          fontSize: context.adaptiveTextSize(20),
        )),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: context.adaptiveIconSize(20)),
                onPressed: _isGenerating ? null : _resetToInput,
              )
            : null,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedAmbientBackground()),
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
                      .animate(animation),
                  child: child,
                ),
              ),
              child: _currentStep == 0
                  ? _buildInputStep()
                  : _currentStep == 1
                      ? _buildLoadingStep()
                      : _buildResultStep(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 0: Input ──────────────────────────────────────────────

  Widget _buildInputStep() {
    return CenteredContent(
      maxWidth: 900,
      child: SingleChildScrollView(
        key: const ValueKey('input'),
        padding: EdgeInsets.symmetric(
          horizontal: context.adaptiveSpacing(20), 
          vertical: context.adaptiveSpacing(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: context.adaptiveSpacing(24)),
            _buildInputTabs(),
            SizedBox(height: context.adaptiveSpacing(16)),
            if (_inputTab == 0) _buildUrlInput() else _buildJdInput(),
            SizedBox(height: context.adaptiveSpacing(20)),
            _buildStyleSelector(),
            SizedBox(height: context.adaptiveSpacing(20)),
            if (_errorMessage != null) _buildErrorBanner(),
            SizedBox(height: context.adaptiveSpacing(12)),
            _buildGenerateButton(),
            SizedBox(height: context.adaptiveSpacing(32)),
            _buildHistorySection(),
            SizedBox(height: context.adaptiveSpacing(40)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
          ).createShader(bounds),
          child: Text(
            'AI Resume Tailor',
            style: GoogleFonts.outfit(
              fontSize: context.adaptiveTextSize(30),
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(height: context.adaptiveSpacing(6)),
        Text(
          'Paste a job URL or description. Get a perfectly tailored, ATS-optimized LaTeX resume in seconds.',
          style: TextStyle(
            color: AppColors.onSurface.withValues(alpha: 0.7),
            fontSize: context.adaptiveTextSize(14),
            height: 1.4,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.05);
  }

  Widget _buildInputTabs() {
    return GlassContainer(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _tabButton('Paste URL', 0, Icons.link_rounded),
          const SizedBox(width: 4),
          _tabButton('Paste JD', 1, Icons.description_rounded),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index, IconData icon) {
    final selected = _inputTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _inputTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: EdgeInsets.symmetric(vertical: context.adaptiveSpacing(12)),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon, 
                size: context.adaptiveIconSize(18), 
                color: selected ? AppColors.primary : AppColors.onSurface.withValues(alpha: 0.5),
              ),
              SizedBox(width: context.adaptiveSpacing(8)),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.primary : AppColors.onSurface.withValues(alpha: 0.5),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: context.adaptiveTextSize(14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUrlInput() {
    return GlassContainer(
      padding: EdgeInsets.all(context.adaptiveSpacing(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Job Posting URL', 
            style: TextStyle(
              color: AppColors.onSurface.withValues(alpha: 0.7), 
              fontSize: context.adaptiveTextSize(12), 
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: context.adaptiveSpacing(8)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  style: TextStyle(color: AppColors.onBackground, fontSize: context.adaptiveTextSize(14)),
                  decoration: InputDecoration(
                    hintText: 'https://linkedin.com/jobs/view/...',
                    hintStyle: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: AppColors.background.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: context.adaptiveSpacing(16), 
                      vertical: context.adaptiveSpacing(14),
                    ),
                    prefixIcon: Icon(Icons.link, size: context.adaptiveIconSize(20), color: AppColors.primary),
                  ),
                ),
              ),
              SizedBox(width: context.adaptiveSpacing(12)),
              _isScraping
                  ? SizedBox(
                      width: context.adaptiveSpacing(48),
                      height: context.adaptiveSpacing(48),
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                    )
                  : Material(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: _scrapeUrl,
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: context.adaptiveSpacing(48),
                          height: context.adaptiveSpacing(48),
                          child: Icon(Icons.download_rounded, color: Colors.white, size: context.adaptiveIconSize(24)),
                        ),
                      ),
                    ),
            ],
          ),
          if (_scrapedJob != null) ...[
            SizedBox(height: context.adaptiveSpacing(12)),
            Container(
              padding: EdgeInsets.all(context.adaptiveSpacing(12)),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: AppColors.success, size: context.adaptiveIconSize(18)),
                  SizedBox(width: context.adaptiveSpacing(8)),
                  Expanded(
                    child: Text(
                      '${_scrapedJob!['title']} at ${_scrapedJob!['company']}',
                      style: TextStyle(
                        color: AppColors.success, 
                        fontSize: context.adaptiveTextSize(13), 
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildJdInput() {
    return GlassContainer(
      padding: EdgeInsets.all(context.adaptiveSpacing(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Job Description', 
                style: TextStyle(
                  color: AppColors.onSurface.withValues(alpha: 0.7), 
                  fontSize: context.adaptiveTextSize(12), 
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${_jdController.text.length} chars', 
                style: TextStyle(
                  color: AppColors.onSurface.withValues(alpha: 0.4), 
                  fontSize: context.adaptiveTextSize(11),
                ),
              ),
            ],
          ),
          SizedBox(height: context.adaptiveSpacing(8)),
          TextField(
            controller: _jdController,
            maxLines: 10,
            minLines: 6,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              color: AppColors.onBackground, 
              fontSize: context.adaptiveTextSize(13), 
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: 'Paste the full job description here...\n\nInclude requirements, responsibilities, and qualifications for the best tailoring results.',
              hintStyle: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.3)),
              filled: true,
              fillColor: AppColors.background.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.all(context.adaptiveSpacing(16)),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildStyleSelector() {
    final styles = [
      {'value': 'classic', 'label': 'Classic ATS', 'subtitle': 'Serif, 1-Col', 'icon': Icons.description_rounded},
      {'value': 'modern', 'label': 'Modern Tech', 'subtitle': 'Sans, Blue', 'icon': Icons.auto_awesome_rounded},
      {'value': 'elegant', 'label': 'Elegant', 'subtitle': 'Charter, HQ', 'icon': Icons.history_edu_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RESUME STYLE',
          style: TextStyle(
            color: AppColors.onSurface.withValues(alpha: 0.5),
            fontSize: context.adaptiveTextSize(11),
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: context.adaptiveSpacing(12)),
        Row(
          children: styles.map((s) {
            final selected = _styleHint == s['value'];
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _styleHint = s['value'] as String);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: EdgeInsets.only(
                    right: s['value'] == 'elegant' ? 0 : context.adaptiveSpacing(8),
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: context.adaptiveSpacing(16), 
                    horizontal: context.adaptiveSpacing(8),
                  ),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.outline.withValues(alpha: 0.2),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        s['icon'] as IconData,
                        size: context.adaptiveIconSize(24),
                        color: selected ? AppColors.primary : AppColors.onSurface.withValues(alpha: 0.4),
                      ),
                      SizedBox(height: context.adaptiveSpacing(8)),
                      Text(
                        s['label'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected ? Colors.white : AppColors.onSurface.withValues(alpha: 0.7),
                          fontSize: context.adaptiveTextSize(12),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        s['subtitle'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.onSurface.withValues(alpha: 0.4),
                          fontSize: context.adaptiveTextSize(10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: EdgeInsets.all(context.adaptiveSpacing(12)),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: context.adaptiveIconSize(20)),
          SizedBox(width: context.adaptiveSpacing(10)),
          Expanded(
            child: Text(
              _errorMessage ?? '',
              style: TextStyle(color: AppColors.error, fontSize: context.adaptiveTextSize(13)),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: context.adaptiveIconSize(18), color: AppColors.error),
            onPressed: () => setState(() => _errorMessage = null),
          ),
        ],
      ),
    ).animate().fadeIn().shakeX(amount: 3);
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isGenerating ? null : _generateResume,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: context.adaptiveIconSize(20)),
            SizedBox(width: context.adaptiveSpacing(10)),
            Text(
              'Generate Tailored Resume',
              style: GoogleFonts.outfit(
                fontSize: context.adaptiveTextSize(16), 
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
  }

  // ─── History ────────────────────────────────────────────────────

  Widget _buildHistorySection() {
    if (_isLoadingHistory) return const SizedBox.shrink();
    if (_history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECENT TAILORED RESUMES',
          style: TextStyle(
            color: AppColors.onSurface.withValues(alpha: 0.5), 
            fontSize: context.adaptiveTextSize(11), 
            fontWeight: FontWeight.w800, 
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: context.adaptiveSpacing(12)),
        ...List.generate(_history.length, (i) {
          final item = _history[i];
          final score = item['tailoring_score'] ?? 0;
          return Padding(
            padding: EdgeInsets.only(bottom: context.adaptiveSpacing(10)),
            child: GlassContainer(
              padding: EdgeInsets.all(context.adaptiveSpacing(14)),
              child: InkWell(
                onTap: () => _loadTailoredResume(item['id']),
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  children: [
                    Container(
                      width: context.adaptiveSpacing(44),
                      height: context.adaptiveSpacing(44),
                      decoration: BoxDecoration(
                        color: _getScoreColor(score).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '$score%',
                          style: TextStyle(
                            color: _getScoreColor(score), 
                            fontWeight: FontWeight.w800, 
                            fontSize: context.adaptiveTextSize(13),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: context.adaptiveSpacing(14)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['job_title'] ?? 'Unknown Position',
                            style: TextStyle(
                              fontWeight: FontWeight.w700, 
                              fontSize: context.adaptiveTextSize(14), 
                              color: AppColors.onBackground,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item['company'] ?? ''} • ${item['style_used'] ?? ''}',
                            style: TextStyle(
                              fontSize: context.adaptiveTextSize(12), 
                              color: AppColors.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded, 
                      color: AppColors.primary, 
                      size: context.adaptiveIconSize(22),
                    ),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(delay: (i * 80).ms).slideX(begin: 0.05);
        }),
      ],
    );
  }

  // ─── Step 1: Loading/Analyzing ──────────────────────────────────

  Widget _buildLoadingStep() {
    return Center(
      key: const ValueKey('loading'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: context.adaptiveSpacing(100),
                height: context.adaptiveSpacing(100),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.3 + _pulseController.value * 0.3),
                      AppColors.secondary.withValues(alpha: 0.1),
                    ],
                  ),
                ),
                child: Icon(Icons.psychology_rounded, size: context.adaptiveIconSize(48), color: AppColors.primary),
              );
            },
          ),
          SizedBox(height: context.adaptiveSpacing(32)),
          Text(
            'Analyzing Job & Tailoring Resume',
            style: GoogleFonts.outfit(
              fontSize: context.adaptiveTextSize(20), 
              fontWeight: FontWeight.w700, 
              color: AppColors.onBackground,
            ),
          ),
          SizedBox(height: context.adaptiveSpacing(12)),
          Text(
            'This may take 30-60 seconds...',
            style: TextStyle(
              color: AppColors.onSurface.withValues(alpha: 0.5), 
              fontSize: context.adaptiveTextSize(14),
            ),
          ),
          SizedBox(height: context.adaptiveSpacing(24)),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: AppColors.surface,
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  // ─── Step 2: Result ─────────────────────────────────────────────

  Widget _buildResultStep() {
    if (_result == null) return const SizedBox.shrink();

    final jobTitle = _result!['job_title'] ?? 'Position';
    final company = _result!['company'] ?? 'Company';
    final latexCode = _result!['latex_code'] ?? '';
    final matchSummary = _result!['match_summary'] ?? {};
    final score = matchSummary['tailoring_score'] ?? 0;
    final matched = (matchSummary['matched_skills'] as List?)?.cast<String>() ?? [];
    final missing = (matchSummary['missing_skills'] as List?)?.cast<String>() ?? [];
    final strategy = matchSummary['strategy'] ?? '';

    return CenteredContent(
      maxWidth: 1000,
      child: SingleChildScrollView(
        key: const ValueKey('result'),
        padding: EdgeInsets.symmetric(
          horizontal: context.adaptiveSpacing(20), 
          vertical: context.adaptiveSpacing(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success header
            GlassContainer(
              padding: EdgeInsets.all(context.adaptiveSpacing(20)),
              borderColor: AppColors.success.withValues(alpha: 0.3),
              child: Row(
                children: [
                  Container(
                    width: context.adaptiveSpacing(56),
                    height: context.adaptiveSpacing(56),
                    decoration: BoxDecoration(
                      color: _getScoreColor(score).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        '$score%', 
                        style: TextStyle(
                          color: _getScoreColor(score), 
                          fontSize: context.adaptiveTextSize(20), 
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: context.adaptiveSpacing(16)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          jobTitle, 
                          style: GoogleFonts.outfit(
                            fontSize: context.adaptiveTextSize(18), 
                            fontWeight: FontWeight.w700, 
                            color: AppColors.onBackground,
                          ),
                        ),
                        Text(
                          company, 
                          style: TextStyle(
                            color: AppColors.onSurface.withValues(alpha: 0.6), 
                            fontSize: context.adaptiveTextSize(14),
                          ),
                        ),
                        if (strategy.isNotEmpty) ...[
                          SizedBox(height: context.adaptiveSpacing(4)),
                          Text(
                            strategy, 
                            style: TextStyle(
                              color: AppColors.primary.withValues(alpha: 0.8), 
                              fontSize: context.adaptiveTextSize(12), 
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: -0.05),
  
            SizedBox(height: context.adaptiveSpacing(16)),
  
            // Skills match
            if (matched.isNotEmpty || missing.isNotEmpty)
              GlassContainer(
                padding: EdgeInsets.all(context.adaptiveSpacing(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TAILORING INSIGHTS', 
                      style: TextStyle(
                        color: AppColors.onSurface.withValues(alpha: 0.5), 
                        fontSize: context.adaptiveTextSize(11), 
                        fontWeight: FontWeight.w800, 
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: context.adaptiveSpacing(16)),
                    if (matched.isNotEmpty) ...[
                      Text(
                        'Strengthened Keywords', 
                        style: TextStyle(
                          color: AppColors.success, 
                          fontSize: context.adaptiveTextSize(12), 
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: context.adaptiveSpacing(8)),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: matched.map((s) => _buildSkillTag(s, AppColors.success)).toList(),
                      ),
                      SizedBox(height: context.adaptiveSpacing(16)),
                    ],
                    if (missing.isNotEmpty) ...[
                      Text(
                        'Missing (Suggested to add manually)', 
                        style: TextStyle(
                          color: AppColors.error, 
                          fontSize: context.adaptiveTextSize(12), 
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: context.adaptiveSpacing(8)),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: missing.map((s) => _buildSkillTag(s, AppColors.error)).toList(),
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms),
  
            SizedBox(height: context.adaptiveSpacing(16)),
  
            // Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _viewPdfPreview,
                    icon: Icon(Icons.picture_as_pdf_rounded, size: context.adaptiveIconSize(20)),
                    label: Text(
                      'Preview PDF',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: context.adaptiveTextSize(14)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: context.adaptiveSpacing(16)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                SizedBox(width: context.adaptiveSpacing(12)),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyToClipboard,
                    icon: Icon(Icons.copy_rounded, size: context.adaptiveIconSize(20)),
                    label: Text(
                      'Copy LaTeX',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: context.adaptiveTextSize(14)),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.onBackground,
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                      padding: EdgeInsets.symmetric(vertical: context.adaptiveSpacing(16)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 200.ms),
  
            // Latex Code Preview
            GlassContainer(
              padding: EdgeInsets.all(context.adaptiveSpacing(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'LATEX CODE PREVIEW', 
                        style: TextStyle(
                          color: AppColors.onSurface.withValues(alpha: 0.5), 
                          fontSize: context.adaptiveTextSize(11), 
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Read-only', 
                        style: TextStyle(
                          color: AppColors.onSurface.withValues(alpha: 0.3), 
                          fontSize: context.adaptiveTextSize(10),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.adaptiveSpacing(12)),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(context.adaptiveSpacing(12)),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      latexCode.length > 500 ? '${latexCode.substring(0, 500)}...' : latexCode,
                      style: GoogleFonts.firaCode(
                        fontSize: context.adaptiveTextSize(10), 
                        color: Colors.white70, 
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillTag(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.adaptiveSpacing(10), 
        vertical: context.adaptiveSpacing(5),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: context.adaptiveTextSize(11), fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return Colors.orange;
    return AppColors.error;
  }
}
