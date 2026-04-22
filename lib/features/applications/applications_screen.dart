
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_animate/flutter_animate.dart';
import '../../shared/widgets/glass_container.dart';
import '../../shared/widgets/animated_ambient_background.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/responsive_utils.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  List<dynamic> _applications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchApplications();
  }

  Future<void> _fetchApplications() async {
    try {
      setState(() => _isLoading = true);
      final response = await apiClient.get('/api/user/applications');
      if (mounted) {
        setState(() {
          _applications = response.data as List? ?? [];
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        String errorMsg;
        final errStr = e.toString();
        if (errStr.contains('SESSION_EXPIRED')) {
          errorMsg = 'Session expired. Please login again.';
        } else if (errStr.contains('timed out')) {
          errorMsg = 'Connection timed out. Check your internet.';
        } else {
          errorMsg = 'Failed to load history';
        }

        setState(() {
          _error = errorMsg;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
          child: Text(
            'Application History',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: context.adaptiveTextSize(20),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: context.adaptiveIconSize(20)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedAmbientBackground()),
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _error != null
                  ? _buildErrorState()
                  : _applications.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _fetchApplications,
                          color: AppColors.primary,
                          child: CenteredContent(
                            child: RepaintBoundary(
                              child: _buildApplicationsList(),
                            ),
                          ),
                        ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.adaptiveSpacing(32)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_rounded, 
                 color: AppColors.error, 
                 size: context.adaptiveIconSize(64)),
            SizedBox(height: context.adaptiveSpacing(16)),
            Text(
              'Sync Interrupted',
              style: GoogleFonts.outfit(
                fontSize: context.adaptiveTextSize(20), 
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: context.adaptiveSpacing(8)),
            Text(
              _error ?? 'An unexpected error occurred while loading your history.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.onSurface.withValues(alpha: 0.6),
                fontSize: context.adaptiveTextSize(14),
              ),
            ),
            SizedBox(height: context.adaptiveSpacing(24)),
            ElevatedButton.icon(
              onPressed: _fetchApplications,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Connection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: context.adaptiveSpacing(24), 
                  vertical: context.adaptiveSpacing(12),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, 
               color: AppColors.onSurface.withValues(alpha: 0.2), 
               size: context.adaptiveIconSize(64)),
          SizedBox(height: context.adaptiveSpacing(16)),
          Text(
            'No applications yet',
            style: GoogleFonts.outfit(
              fontSize: context.adaptiveTextSize(18),
              color: AppColors.onSurface.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: context.adaptiveSpacing(8)),
          Text(
            'Start your auto-applier to see results here.',
            style: TextStyle(
              color: AppColors.onSurface.withValues(alpha: 0.3),
              fontSize: context.adaptiveTextSize(14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsList() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: context.isMobile ? 20 : 40, 
        vertical: 16,
      ),
      itemCount: _applications.length,
      itemBuilder: (context, index) {
        final app = _applications[index];
        
        final rawTitle = app['job_title'] ?? app['title'];
        final title = (rawTitle == null || rawTitle.toString().trim().isEmpty) 
            ? 'Unknown Role' 
            : rawTitle.toString();
            
        final rawCompany = app['company_name'] ?? app['company'];
        final company = (rawCompany == null || rawCompany.toString().trim().isEmpty) 
            ? 'Unknown Company' 
            : rawCompany.toString();
            
        final status = app['status']?.toString() ?? 'Pending';
        
        DateTime? date;
        if (app['created_at'] != null) {
          try {
            if (app['created_at'] is String) {
               date = DateTime.tryParse(app['created_at'])?.toLocal();
            } else if (app['created_at'] is DateTime) {
               date = (app['created_at'] as DateTime).toLocal();
            }
          } catch (_) {}
        }

        return RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GlassContainer(
              padding: EdgeInsets.all(context.adaptiveSpacing(16)),
              useBlur: false, // Optimize performance in long lists
              child: Row(
              children: [
                Container(
                  width: context.adaptiveIconSize(52),
                  height: context.adaptiveIconSize(52),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      company.isNotEmpty ? company[0].toUpperCase() : '?',
                      style: GoogleFonts.outfit(
                        fontSize: context.adaptiveTextSize(20),
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
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
                        title,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: context.adaptiveTextSize(15),
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        company,
                        style: GoogleFonts.inter(
                          fontSize: context.adaptiveTextSize(13),
                          color: AppColors.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (date != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${date.day}/${date.month}/${date.year}',
                          style: GoogleFonts.inter(
                            fontSize: context.adaptiveTextSize(10),
                            color: AppColors.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.adaptiveSpacing(12), 
                    vertical: context.adaptiveSpacing(6),
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: context.adaptiveTextSize(10),
                      fontWeight: FontWeight.w800,
                      color: _getStatusColor(status),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ).animate().fadeIn(duration: 400.ms, delay: ((index % 15) * 40).ms).slideX(begin: 0.05);
      },
    );
  }

  Color _getStatusColor(String status) {
    status = status.toLowerCase();
    if (status.contains('applied') || status.contains('pending')) return AppColors.primary;
    if (status.contains('interview')) return AppColors.tertiary;
    if (status.contains('success') || status.contains('offer')) return AppColors.success;
    if (status.contains('reject')) return AppColors.error;
    return AppColors.outline;
  }
}
