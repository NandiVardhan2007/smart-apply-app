import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/glass_container.dart';
import '../../shared/widgets/animated_ambient_background.dart';
import '../dashboard/providers/dashboard_provider.dart';
import '../../core/utils/responsive_utils.dart';


class MyResumeScreen extends ConsumerStatefulWidget {
  const MyResumeScreen({super.key});

  @override
  ConsumerState<MyResumeScreen> createState() => _MyResumeScreenState();
}

class _MyResumeScreenState extends ConsumerState<MyResumeScreen> {
  bool _isLoading = true;
  bool _isUploading = false;
  List<dynamic> _resumes = [];
  Map<String, dynamic>? _latestScan;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final profileRes = await apiClient.get(ApiConstants.profile);
      final historyRes = await apiClient.get('/api/ats/history');

      if (mounted) {
        setState(() {
          _resumes = profileRes.data['resumes'] ?? [];
          final List scans = historyRes.data['scans'] ?? [];
          if (scans.isNotEmpty) _latestScan = scans.first;
        });
      }
    } catch (e) {
      debugPrint('Error loading resume info: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadResume() async {
    final nameController = TextEditingController();
    
    // Ask for a label/name first
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Label your resume', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: 'e.g., Frontend Developer, Generic, Python Expert',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Upload'),
          ),
        ],
      ),
    );

    if (label == null || label.isEmpty) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null) return;

    setState(() => _isUploading = true);

    try {
      final file = result.files.first;
      late List<int> bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else {
        bytes = await File(file.path!).readAsBytes();
      }

      await apiClient.post(
        ApiConstants.uploadResume,
        data: dio.FormData.fromMap({
          'file': dio.MultipartFile.fromBytes(bytes, filename: file.name),
          'resume_name': label,
        }),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resume uploaded successfully!'), backgroundColor: AppColors.success),
        );
        ref.invalidate(dashboardProvider);
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _viewResume(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open resume: $e')));
      }
    }
  }

  Future<void> _setDefault(String id) async {
    try {
      await apiClient.patch(ApiConstants.setDefaultResume(id));
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Default resume updated'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to set default: $e')));
      }
    }
  }

  Future<void> _deleteResume(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Resume?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete', style: TextStyle(color: AppColors.error))
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await apiClient.delete(ApiConstants.deleteResume(id));
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Resumes', 
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: context.adaptiveTextSize(18),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: context.adaptiveIconSize(20)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedAmbientBackground()),
          _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: CenteredContent(
                    maxWidth: 900,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(context.adaptiveSpacing(24)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          SizedBox(height: context.adaptiveSpacing(32)),
                          _buildResumeList(),
                          SizedBox(height: context.adaptiveSpacing(32)),
                          _buildAtsInsightCard(),
                          SizedBox(height: context.adaptiveSpacing(40)),
                        ],
                      ),
                    ),
                  ),
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _pickAndUploadResume,
        backgroundColor: AppColors.primary,
        icon: _isUploading 
            ? SizedBox(
                width: context.adaptiveIconSize(20), 
                height: context.adaptiveIconSize(20), 
                child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Icon(Icons.add, size: context.adaptiveIconSize(20)),
        label: Text(
          _isUploading ? 'Uploading...' : 'Add New Resume',
          style: TextStyle(fontSize: context.adaptiveTextSize(14)),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         ShaderMask(
          shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
          child: Text(
            'Global Assets',
            style: GoogleFonts.outfit(
              fontSize: context.adaptiveTextSize(32), 
              fontWeight: FontWeight.bold, 
              color: Colors.white,
            ),
          ),
        ),
        Text(
          'Manage your career identities and documents.',
          style: TextStyle(
            color: AppColors.onSurface.withValues(alpha: 0.7), 
            fontSize: context.adaptiveTextSize(14),
          ),
        ),
      ],
    ).animate().fadeIn().slideX(begin: -0.1);
  }

  Widget _buildResumeList() {
    if (_resumes.isEmpty) {
      return GlassContainer(
        padding: EdgeInsets.all(context.adaptiveSpacing(40)),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.description_outlined, 
                size: context.adaptiveIconSize(48), 
                color: AppColors.onSurface.withValues(alpha: 0.3),
              ),
              SizedBox(height: context.adaptiveSpacing(16)),
              Text(
                'No resumes found. Upload your first one to get started!', 
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: context.adaptiveTextSize(14)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _resumes.length,
      separatorBuilder: (context, index) => SizedBox(height: context.adaptiveSpacing(16)),
      itemBuilder: (context, index) {
        final resume = _resumes[index];
        final isDefault = resume['is_default'] == true;
        
        return GlassContainer(
          padding: EdgeInsets.all(context.adaptiveSpacing(16)),
          borderColor: isDefault ? AppColors.primary.withValues(alpha: 0.5) : null,
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(context.adaptiveSpacing(12)),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.picture_as_pdf, 
                      color: AppColors.primary, 
                      size: context.adaptiveIconSize(24),
                    ),
                  ),
                  SizedBox(width: context.adaptiveSpacing(16)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                resume['name'] ?? 'Untitled Resume',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: context.adaptiveTextSize(16),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isDefault) ...[
                              SizedBox(width: context.adaptiveSpacing(8)),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.adaptiveSpacing(8), 
                                  vertical: context.adaptiveSpacing(2),
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  'DEFAULT', 
                                  style: TextStyle(
                                    color: AppColors.success, 
                                    fontSize: context.adaptiveTextSize(10), 
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Added ${resume['created_at'] != null ? resume['created_at'].split('T')[0] : 'Unknown'}',
                          style: TextStyle(
                            fontSize: context.adaptiveTextSize(12), 
                            color: AppColors.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    iconSize: context.adaptiveIconSize(24),
                    onSelected: (val) {
                      if (val == 'view') _viewResume(resume['url']);
                      if (val == 'default') _setDefault(resume['id']);
                      if (val == 'delete') _deleteResume(resume['id']);
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'view', 
                        child: ListTile(
                          leading: Icon(Icons.visibility, size: context.adaptiveIconSize(20)), 
                          title: Text('View', style: TextStyle(fontSize: context.adaptiveTextSize(14))), 
                          dense: true,
                        ),
                      ),
                      if (!isDefault)
                        PopupMenuItem(
                          value: 'default', 
                          child: ListTile(
                            leading: Icon(Icons.star, size: context.adaptiveIconSize(20)), 
                            title: Text('Set as Default', style: TextStyle(fontSize: context.adaptiveTextSize(14))), 
                            dense: true,
                          ),
                        ),
                      PopupMenuItem(
                        value: 'delete', 
                        child: ListTile(
                          leading: Icon(Icons.delete, color: AppColors.error, size: context.adaptiveIconSize(20)), 
                          title: Text(
                            'Delete', 
                            style: TextStyle(color: AppColors.error, fontSize: context.adaptiveTextSize(14)),
                          ), 
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.1);
      },
    );
  }

  Widget _buildAtsInsightCard() {
    if (_latestScan == null) return const SizedBox.shrink();

    final score = _latestScan?['overall_score'] ?? 0;
    final grade = _latestScan?['overall_grade'] ?? 'N/A';
    final summary = _latestScan?['summary'] ?? 'No analysis summary available.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LATEST ATS INSIGHT',
          style: TextStyle(
            fontSize: context.adaptiveTextSize(12), 
            fontWeight: FontWeight.w800, 
            color: AppColors.primary, 
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: context.adaptiveSpacing(12)),
        GlassContainer(
          padding: EdgeInsets.all(context.adaptiveSpacing(20)),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: context.adaptiveSpacing(50),
                    height: context.adaptiveSpacing(50),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _getScoreColor(score), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        grade,
                        style: TextStyle(
                          fontSize: context.adaptiveTextSize(16), 
                          fontWeight: FontWeight.bold, 
                          color: _getScoreColor(score),
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
                          'Score: $score%', 
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: context.adaptiveTextSize(16),
                          ),
                        ),
                        Text(
                          'Based on your last scan', 
                          style: TextStyle(
                            fontSize: context.adaptiveTextSize(12), 
                            color: AppColors.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.adaptiveSpacing(16)),
              Text(
                summary, 
                style: TextStyle(fontSize: context.adaptiveTextSize(13), height: 1.4), 
                maxLines: 2, 
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return Colors.orange;
    return AppColors.error;
  }
}
