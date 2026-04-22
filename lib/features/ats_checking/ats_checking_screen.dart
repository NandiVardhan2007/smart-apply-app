import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/glass_container.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../dashboard/providers/dashboard_provider.dart';
import '../../core/utils/responsive_utils.dart';


class AtsCheckingScreen extends ConsumerStatefulWidget {
  const AtsCheckingScreen({super.key});

  @override
  ConsumerState<AtsCheckingScreen> createState() => _AtsCheckingScreenState();
}

class _AtsCheckingScreenState extends ConsumerState<AtsCheckingScreen>
    with TickerProviderStateMixin {
  // --- State ---
  _ScreenState _screenState = _ScreenState.upload;
  Map<String, dynamic>? _scanResult;
  List<Map<String, dynamic>> _scanHistory = [];
  String? _error;

  // Upload fields
  PlatformFile? _selectedFile;
  final TextEditingController _jobDescController = TextEditingController();
  final TextEditingController _jobTitleController = TextEditingController();

  // Scanning animation
  late AnimationController _pulseController;
  late AnimationController _scoreAnimController;
  String _scanningStatus = 'Initializing scanner...';
  int _scanningStep = 0;
  Timer? _scanningTimer;

  static const _scanSteps = [
    'Extracting resume text...',
    'Analyzing keyword relevance...',
    'Checking formatting & structure...',
    'Evaluating section completeness...',
    'Scanning for quantified achievements...',
    'Assessing action verbs usage...',
    'Measuring readability & clarity...',
    'Detecting ATS-hostile elements...',
    'Generating improvement plan...',
    'Finalizing your report...',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scoreAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _loadHistory();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scoreAnimController.dispose();
    _scanningTimer?.cancel();
    _jobDescController.dispose();
    _jobTitleController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // DATA METHODS
  // ─────────────────────────────────────────────

  Future<void> _loadHistory() async {
    try {
      final response = await apiClient.get('/api/ats/history');
      if (mounted) {
        setState(() {
          _scanHistory = List<Map<String, dynamic>>.from(
            (response.data['scans'] as List).map((e) => Map<String, dynamic>.from(e)),
          );
        });
      }
    } catch (_) {
      // Silent fail for history — not critical
    }
  }

  Future<void> _startScan() async {
    if (_selectedFile == null) return;

    setState(() {
      _screenState = _ScreenState.scanning;
      _scanningStep = 0;
      _scanningStatus = _scanSteps[0];
      _error = null;
    });

    // Start step animation
    _scanningTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_scanningStep < _scanSteps.length - 1) {
        setState(() {
          _scanningStep++;
          _scanningStatus = _scanSteps[_scanningStep];
        });
      } else {
        // All simulated steps done, but API still running
        setState(() {
          _scanningStatus = 'AI is finalizing your report... almost there!';
        });
      }
    });


    try {
      final fields = <String, String>{};
      if (_jobDescController.text.trim().isNotEmpty) {
        fields['job_description'] = _jobDescController.text.trim();
      }
      if (_jobTitleController.text.trim().isNotEmpty) {
        fields['job_title'] = _jobTitleController.text.trim();
      }

      final Response response;
      if (_selectedFile!.bytes != null) {
        response = await apiClient.uploadFileBytes(
          '/api/ats/scan',
          fileBytes: _selectedFile!.bytes!,
          fileName: _selectedFile!.name,
          fields: fields.isEmpty ? null : fields,
        );
      } else if (_selectedFile!.path != null) {
        response = await apiClient.uploadFile(
          '/api/ats/scan',
          filePath: _selectedFile!.path!,
          fileName: _selectedFile!.name,
          fields: fields.isEmpty ? null : fields,
        );
      } else {
        throw 'Could not read the selected file.';
      }

      _scanningTimer?.cancel();

      if (mounted) {
        setState(() {
          _scanResult = Map<String, dynamic>.from(response.data);
          _screenState = _ScreenState.results;
        });
        _scoreAnimController.forward(from: 0);
        _loadHistory(); // refresh local history in background
        
        // Trigger global dashboard refresh to update stats/scores
        ref.invalidate(dashboardProvider);
      }
    } catch (e) {
      _scanningTimer?.cancel();
      if (mounted) {
        setState(() {
          _error = 'Analysis failed: ${e.toString()}';
          _screenState = _ScreenState.upload;
        });
      }
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
        _error = null;
      });
    }
  }

  void _viewHistoryScan(Map<String, dynamic> scan) async {
    final scanId = scan['id'];
    if (scanId == null) return;

    setState(() {
      _screenState = _ScreenState.scanning;
      _scanningStep = 0;
      _scanningStatus = _scanSteps[0];
      _error = null;
    });

    // Start step animation
    _scanningTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_scanningStep < _scanSteps.length - 1) {
        setState(() {
          _scanningStep++;
          _scanningStatus = _scanSteps[_scanningStep];
        });
      } else {
        setState(() {
          _scanningStatus = 'Finalizing your analysis...';
        });
        timer.cancel();
      }
    });

    try {
      final response = await apiClient.get('/api/ats/scan/$scanId');
      _scanningTimer?.cancel();
      if (mounted) {
        final data = response.data;
        if (data == null) throw 'No data found for this scan';
        
        setState(() {
          _scanResult = Map<String, dynamic>.from(data);
          _screenState = _ScreenState.results;
        });
        _scoreAnimController.forward(from: 0);
      }
    } catch (e) {
      _scanningTimer?.cancel();
      if (mounted) {
        setState(() {
          _error = 'Failed to load history: ${e.toString()}';
          _screenState = _ScreenState.upload;
        });
      }
    }
  }

  // ─────────────────────────────────────────────

  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: switch (_screenState) {
          _ScreenState.upload => _buildUploadView(),
          _ScreenState.scanning => _buildScanningView(),
          _ScreenState.results => _buildResultsView(),
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // 1. UPLOAD VIEW
  // ═══════════════════════════════════════════════

  Widget _buildUploadView() {
    return CenteredContent(
      maxWidth: 1000,
      child: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, context.adaptiveSpacing(16), 24, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_ios_new, size: context.adaptiveIconSize(20)),
                  ),
                  SizedBox(width: context.adaptiveSpacing(8)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ATS Optimizer',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontSize: context.adaptiveTextSize(24),
                          ),
                        ),
                        Text(
                          'Professional Resume Analysis & Score Improvement',
                          style: TextStyle(
                            color: AppColors.onSurface.withValues(alpha: 0.6),
                            fontSize: context.adaptiveTextSize(13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
          ),
  
          // Upload Area
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(context.adaptiveSpacing(24)),
              child: Column(
                children: [
                  // File Upload Card
                  GestureDetector(
                    onTap: _pickFile,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: context.adaptiveSpacing(40), 
                        horizontal: context.adaptiveSpacing(24),
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.08),
                            AppColors.secondary.withValues(alpha: 0.05),
                          ],
                        ),
                        border: Border.all(
                          color: _selectedFile != null
                              ? AppColors.success.withValues(alpha: 0.5)
                              : AppColors.primary.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(context.adaptiveSpacing(16)),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _selectedFile != null
                                  ? AppColors.success.withValues(alpha: 0.1)
                                  : AppColors.primary.withValues(alpha: 0.1),
                            ),
                            child: Icon(
                              _selectedFile != null
                                  ? Icons.check_circle_rounded
                                  : Icons.cloud_upload_outlined,
                              color: _selectedFile != null
                                  ? AppColors.success
                                  : AppColors.primary,
                              size: context.adaptiveIconSize(40),
                            ),
                          ),
                          SizedBox(height: context.adaptiveSpacing(16)),
                          Text(
                            _selectedFile != null
                                ? _selectedFile!.name
                                : 'Tap to Upload Resume',
                            style: TextStyle(
                              fontSize: context.adaptiveTextSize(16),
                              fontWeight: FontWeight.w600,
                              color: _selectedFile != null
                                  ? AppColors.success
                                  : AppColors.primary,
                            ),
                          ),
                          SizedBox(height: context.adaptiveSpacing(6)),
                          Text(
                            _selectedFile != null
                                ? '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB • Tap to change'
                                : 'Resumes only (PDF) • Maximum 10MB',
                            style: TextStyle(
                              fontSize: context.adaptiveTextSize(12),
                              color: AppColors.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          if (_selectedFile == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'Please upload a professional resume only. Notes, assignments, or unrelated documents will be rejected.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: context.adaptiveTextSize(10),
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 100.ms).slideY(begin: 0.1),
  
                  SizedBox(height: context.adaptiveSpacing(20)),
  
                  // Job Title (optional)
                  TextField(
                    controller: _jobTitleController,
                    style: TextStyle(fontSize: context.adaptiveTextSize(14)),
                    decoration: InputDecoration(
                      hintText: 'Target Job Title (optional)',
                      prefixIcon: Icon(Icons.work_outline, color: AppColors.onSurface.withValues(alpha: 0.4), size: context.adaptiveIconSize(20)),
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
  
                  SizedBox(height: context.adaptiveSpacing(14)),
  
                  // Job Description (optional)
                  TextField(
                    controller: _jobDescController,
                    maxLines: 4,
                    style: TextStyle(fontSize: context.adaptiveTextSize(14)),
                    decoration: InputDecoration(
                      hintText: 'Paste Job Description for tailored analysis (optional)',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(bottom: 56),
                        child: Icon(Icons.description_outlined, color: AppColors.onSurface.withValues(alpha: 0.4), size: context.adaptiveIconSize(20)),
                      ),
                      alignLabelWithHint: true,
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 300.ms),
  
                  SizedBox(height: context.adaptiveSpacing(24)),
  
                  // Error message
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(context.adaptiveSpacing(14)),
                      margin: const EdgeInsets.only(bottom: 16),
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
                              _error!,
                              style: TextStyle(color: AppColors.error, fontSize: context.adaptiveTextSize(13)),
                            ),
                          ),
                        ],
                      ),
                    ),
  
                  // Scan Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _selectedFile != null ? _startScan : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.surfaceHigh,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: _selectedFile != null ? 8 : 0,
                        shadowColor: AppColors.primary.withValues(alpha: 0.4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.radar, size: context.adaptiveIconSize(22), color: _selectedFile != null ? Colors.white : AppColors.outline),
                          SizedBox(width: context.adaptiveSpacing(10)),
                          Text(
                            'Run ATS Analysis',
                            style: TextStyle(
                              fontSize: context.adaptiveTextSize(16),
                              fontWeight: FontWeight.bold,
                              color: _selectedFile != null ? Colors.white : AppColors.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 400.ms).slideY(begin: 0.1),
  
                  SizedBox(height: context.adaptiveSpacing(16)),
  
                  // What we check
                  _buildWhatWeCheck(),
                ],
              ),
            ),
          ),
  
          // Scan History
          if (_scanHistory.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, context.adaptiveSpacing(16)),
                child: Text(
                  'Previous Scans',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: context.adaptiveTextSize(20),
                  ),
                ),
              ),
            ),
          if (_scanHistory.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final scan = _scanHistory[index];
                  return _buildHistoryCard(scan, index);
                },
                childCount: _scanHistory.length,
              ),
            ),
  
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildWhatWeCheck() {
    final items = [
      ('Keywords', Icons.search, AppColors.primary),
      ('Formatting', Icons.format_list_bulleted, AppColors.secondary),
      ('Sections', Icons.checklist, AppColors.tertiary),
      ('Achievements', Icons.trending_up, AppColors.success),
      ('Action Verbs', Icons.edit_note, const Color(0xFFFF6B6B)),
      ('Readability', Icons.visibility, const Color(0xFF00D2FF)),
      ('ATS Traps', Icons.warning_amber, const Color(0xFFFF9F43)),
      ('JD Match', Icons.gps_fixed, const Color(0xFFA29BFE)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: context.adaptiveSpacing(24)),
        Text(
          'What We Analyze',
          style: TextStyle(
            fontSize: context.adaptiveTextSize(14),
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface.withValues(alpha: 0.5),
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: context.adaptiveSpacing(12)),
        Wrap(
          spacing: context.adaptiveSpacing(8),
          runSpacing: context.adaptiveSpacing(8),
          children: items.map((item) {
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.adaptiveSpacing(12), 
                vertical: context.adaptiveSpacing(8),
              ),
              decoration: BoxDecoration(
                color: item.$3.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: item.$3.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.$2, size: context.adaptiveIconSize(14), color: item.$3),
                  SizedBox(width: context.adaptiveSpacing(6)),
                  Text(
                    item.$1,
                    style: TextStyle(
                      fontSize: context.adaptiveTextSize(12), 
                      color: item.$3, 
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms, delay: 500.ms);
  }

  Widget _buildHistoryCard(Map<String, dynamic> scan, int index) {
    final score = scan['overall_score'] ?? 0;
    final grade = scan['overall_grade'] ?? 'N/A';
    final title = scan['job_title'] ?? 'Resume Scan';
    final filename = scan['filename'] ?? '';
    final hasJd = scan['job_description_provided'] == true;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: context.adaptiveSpacing(4)),
      child: GlassContainer(
        padding: EdgeInsets.all(context.adaptiveSpacing(16)),
        child: InkWell(
          onTap: () => _viewHistoryScan(scan),
          borderRadius: BorderRadius.circular(24),
          child: Row(
            children: [
              // Score badge
              Container(
                width: context.adaptiveSpacing(52),
                height: context.adaptiveSpacing(52),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_scoreColor(score), _scoreColor(score).withValues(alpha: 0.6)],
                  ),
                ),
                child: Center(
                  child: Text(
                    grade,
                    style: TextStyle(
                      fontSize: context.adaptiveTextSize(16),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.adaptiveSpacing(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: context.adaptiveTextSize(15))),
                    const SizedBox(height: 3),
                    Text(
                      '$filename${hasJd ? ' • JD matched' : ''}',
                      style: TextStyle(fontSize: context.adaptiveTextSize(12), color: AppColors.onSurface.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
              Text(
                '$score%',
                style: TextStyle(
                  fontSize: context.adaptiveTextSize(20),
                  fontWeight: FontWeight.bold,
                  color: _scoreColor(score),
                ),
              ),
              SizedBox(width: context.adaptiveSpacing(8)),
              Icon(Icons.chevron_right, color: AppColors.outline, size: context.adaptiveIconSize(20)),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: (100 * index).ms).slideX(begin: 0.05);
  }

  // ═══════════════════════════════════════════════
  // 2. SCANNING VIEW
  // ═══════════════════════════════════════════════

  Widget _buildScanningView() {
    final progress = (_scanningStep + 1) / _scanSteps.length;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated radar icon
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.15),
                  child: Container(
                    width: context.adaptiveSpacing(120),
                    height: context.adaptiveSpacing(120),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.25),
                          AppColors.primary.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(Icons.radar, size: context.adaptiveIconSize(56), color: AppColors.primary),
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: context.adaptiveSpacing(40)),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 300,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceHigh,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ),
            SizedBox(height: context.adaptiveSpacing(20)),

            // Status text
            Text(
              _scanningStatus,
              style: TextStyle(fontSize: context.adaptiveTextSize(15), fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Step ${_scanningStep + 1} of ${_scanSteps.length}',
              style: TextStyle(fontSize: context.adaptiveTextSize(12), color: AppColors.onSurface.withValues(alpha: 0.4)),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // 3. RESULTS VIEW
  // ═══════════════════════════════════════════════

  Widget _buildResultsView() {
    if (_scanResult == null) return const Center(child: Text('No results to display.'));

    // Strict type casting to prevent mathematical crashes
    int score = 0;
    try {
      final s = _scanResult!['overall_score'];
      if (s is num) score = s.toInt();
      else if (s is String) score = int.tryParse(s) ?? 0;
    } catch (e) { score = 0; }

    final grade = _scanResult!['overall_grade']?.toString() ?? 'N/A';
    final summary = _scanResult!['summary']?.toString() ?? 'Analysis complete.';
    
    // Safer list extraction to prevent gray screen crashes
    List<Map<String, dynamic>> categories = [];
    try {
      final rawCats = _scanResult!['categories'];
      if (rawCats is List) {
        for (var item in rawCats) {
          if (item is Map) {
            final Map<String, dynamic> normalized = Map<String, dynamic>.from(item);
            // Ensure category score is also safe
            int cScore = 0;
            final cs = normalized['score'];
            if (cs is num) cScore = cs.toInt();
            else if (cs is String) cScore = int.tryParse(cs) ?? 0;
            normalized['score'] = cScore;
            categories.add(normalized);
          }
        }
      }
    } catch (e) { debugPrint('Error parsing categories: $e'); }

    List<String> milestones = [];
    try {
      final rawMilestones = _scanResult!['milestones'];
      if (rawMilestones is List) milestones = List<String>.from(rawMilestones.map((e) => e.toString()));
    } catch (e) { debugPrint('Error parsing milestones: $e'); }

    List<String> drawbacks = [];
    try {
      final rawDrawbacks = _scanResult!['drawbacks'];
      if (rawDrawbacks is List) drawbacks = List<String>.from(rawDrawbacks.map((e) => e.toString()));
    } catch (e) { debugPrint('Error parsing drawbacks: $e'); }

    List<Map<String, dynamic>> improvementPlan = [];
    try {
      final rawPlan = _scanResult!['improvement_plan'];
      if (rawPlan is List) {
        improvementPlan = List<Map<String, dynamic>>.from(rawPlan.map((e) => Map<String, dynamic>.from(e)));
      }
    } catch (e) { debugPrint('Error parsing improvement plan: $e'); }

    return CenteredContent(
      maxWidth: 1100,
      child: CustomScrollView(
        slivers: [
          // Back Button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => setState(() => _screenState = _ScreenState.upload),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  tooltip: 'Back to Upload',
                ),
              ),
            ),
          ),

          // Header / Score

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _buildScoreRing(score, grade, summary),
            ),
          ).animate().fadeIn(duration: 600.ms),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 320,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              delegate: SliverChildBuilderDelegate(

                (context, index) => _buildCategoryCard(categories[index], index),
                childCount: categories.length,
              ),
            ),
          ),

          // Milestones
          if (milestones.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
                child: _buildSectionTitle('🌟 Key Strengths', Icons.auto_awesome_outlined),
              ),
            ),
          if (milestones.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildMilestonesList(milestones),
              ),
            ),

          // Drawbacks
          if (drawbacks.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
                child: _buildSectionTitle('⚠️ Critical Gaps', Icons.warning_amber_rounded),
              ),
            ),
          if (drawbacks.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildDrawbacksList(drawbacks),
              ),
            ),

          // Improvement Plan
          if (improvementPlan.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: _buildSectionTitle('🚀 Improvement Plan', Icons.rocket_launch_outlined),
              ),
            ),
          if (improvementPlan.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: _buildImprovementCard(improvementPlan[index], index),
                ),
                childCount: improvementPlan.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }

  // ─── Score Ring ───
  Widget _buildScoreRing(int score, String grade, String summary) {
    return GlassContainer(
      child: Column(
        children: [
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _scoreAnimController,
            builder: (context, _) {
              final animatedScore = (_scoreAnimController.value * score).toInt();
              final animatedProgress = _scoreAnimController.value * score / 100;
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _scoreColor(score).withValues(alpha: 0.25 * _scoreAnimController.value),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  // Background ring
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 10,
                      backgroundColor: Colors.transparent,
                      color: AppColors.surfaceHigh,
                    ),
                  ),
                  // Animated score ring
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      value: animatedProgress,
                      strokeWidth: 10,
                      backgroundColor: Colors.transparent,
                      color: _scoreColor(score),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  // Center text
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$animatedScore%',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: _scoreColor(score),
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: _scoreColor(score).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Grade $grade',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _scoreColor(score),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            summary,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.onSurface.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.9, 0.9));
  }

  // ─── Category Card ───
  Widget _buildCategoryCard(Map<String, dynamic> category, int index) {
    final name = category['name'] ?? '';
    final catScore = category['score'] ?? 0;
    final catGrade = category['grade'] ?? 'N/A';
    final iconName = category['icon'] ?? 'info';

    final iconData = _mapIcon(iconName);

    return GestureDetector(
      onTap: () => _showCategoryDetail(category),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _scoreColor(catScore).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconData, size: 18, color: _scoreColor(catScore)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _scoreColor(catScore).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    catGrade,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _scoreColor(catScore),
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Mini progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: catScore / 100,
                    minHeight: 5,
                    backgroundColor: AppColors.surfaceHigh,
                    valueColor: AlwaysStoppedAnimation(_scoreColor(catScore)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$catScore%',
                  style: TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: (80 * index).ms).slideY(begin: 0.1, end: 0);
  }

  void _showCategoryDetail(Map<String, dynamic> category) {
    final name = category['name'] ?? '';
    final catScore = category['score'] ?? 0;
    final catGrade = category['grade'] ?? 'N/A';
    final findings = List<String>.from((category['findings'] as List?) ?? []);
    final suggestions = List<String>.from((category['suggestions'] as List?) ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Text(name, style: Theme.of(context).textTheme.titleLarge),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _scoreColor(catScore).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$catScore% ($catGrade)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _scoreColor(catScore),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Findings
                  const Text('📋 Findings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ...findings.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 14, color: AppColors.primary)),
                        Expanded(child: Text(f, style: const TextStyle(fontSize: 14, height: 1.4))),
                      ],
                    ),
                  )),

                  const SizedBox(height: 20),

                  // Suggestions
                  const Text('💡 Suggestions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ...suggestions.map((s) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.tertiary),
                        const SizedBox(width: 10),
                        Expanded(child: Text(s, style: const TextStyle(fontSize: 13, height: 1.4))),
                      ],
                    ),
                  )),

                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Milestones ───
  Widget _buildMilestonesList(List<String> milestones) {
    return GlassContainer(
      child: Column(
        children: milestones.asMap().entries.map((entry) {
          return Padding(
            padding: EdgeInsets.only(bottom: entry.key < milestones.length - 1 ? 12 : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 14, color: AppColors.success),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.value,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: (100 * entry.key).ms).slideX(begin: 0.05);
        }).toList(),
      ),
    );
  }

  // ─── Drawbacks ───
  Widget _buildDrawbacksList(List<String> drawbacks) {
    return GlassContainer(
      child: Column(
        children: drawbacks.asMap().entries.map((entry) {
          return Padding(
            padding: EdgeInsets.only(bottom: entry.key < drawbacks.length - 1 ? 12 : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: AppColors.error),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.value,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: (100 * entry.key).ms).slideX(begin: 0.05);
        }).toList(),
      ),
    );
  }

  // ─── Improvement Card ───
  Widget _buildImprovementCard(Map<String, dynamic> item, int index) {
    final priority = item['priority'] ?? 'MEDIUM';
    final action = item['action'] ?? '';
    final impact = item['impact'] ?? '';
    final details = item['details'] ?? '';

    final priorityColor = switch (priority) {
      'HIGH' => const Color(0xFFFF6B6B),
      'LOW' => AppColors.success,
      _ => AppColors.tertiary,
    };

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  priority,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: priorityColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              if (impact.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_up, size: 14, color: AppColors.success.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(
                      impact,
                      style: TextStyle(fontSize: 11, color: AppColors.success.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            action,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              details,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.onSurface.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: (120 * index).ms).slideY(begin: 0.08);
  }

  // ─── Helpers ───
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Color _scoreColor(int score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.tertiary;
    if (score >= 40) return const Color(0xFFFF9F43);
    return const Color(0xFFFF6B6B);
  }

  IconData _mapIcon(String iconName) {
    return switch (iconName) {
      'search' => Icons.search,
      'format_list_bulleted' => Icons.format_list_bulleted,
      'checklist' => Icons.checklist,
      'trending_up' => Icons.trending_up,
      'edit_note' => Icons.edit_note,
      'visibility' => Icons.visibility,
      'warning' => Icons.warning_amber,
      'target' => Icons.gps_fixed,
      _ => Icons.info_outline,
    };
  }
}

enum _ScreenState { upload, scanning, results }
