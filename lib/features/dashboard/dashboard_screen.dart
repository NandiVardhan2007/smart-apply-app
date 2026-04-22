import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/widgets/glass_container.dart';
import '../../core/constants/app_colors.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/animated_ambient_background.dart';
import '../../core/utils/responsive_utils.dart';
import 'providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Initial fetch happens via provider build
  }

  Future<void> _handleRefresh() async {
    await ref.read(dashboardProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardProvider);

    return dashboardAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (error, stack) {
        final errorStr = error.toString();
        final isAuthExpired = errorStr.contains('401') || errorStr.contains('unauthorized');
        
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.adaptiveSpacing(32)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isAuthExpired ? Icons.lock_clock_rounded : Icons.error_outline,
                    size: context.adaptiveIconSize(64),
                    color: isAuthExpired ? AppColors.warning : AppColors.error,
                  ),
                  SizedBox(height: context.adaptiveSpacing(16)),
                  Text(
                    isAuthExpired ? 'Session Expired' : 'Sync Error',
                    style: GoogleFonts.outfit(
                      fontSize: context.adaptiveTextSize(20), 
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: context.adaptiveSpacing(8)),
                  Text(
                    isAuthExpired
                        ? 'Your security token is no longer valid. Please log in again to continue.'
                        : 'Could not connect to AI services',
                    style: TextStyle(
                      color: AppColors.onSurface.withValues(alpha: 0.6),
                      fontSize: context.adaptiveTextSize(14),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: context.adaptiveSpacing(12)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.adaptiveSpacing(16), 
                      vertical: context.adaptiveSpacing(8),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      errorStr,
                      style: GoogleFonts.robotoMono(
                        fontSize: context.adaptiveTextSize(12),
                        color: AppColors.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: context.adaptiveSpacing(24)),
                  ElevatedButton(
                    onPressed: isAuthExpired
                        ? () => ref.read(authProvider.notifier).logout()
                        : _handleRefresh,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(
                        horizontal: context.adaptiveSpacing(24), 
                        vertical: context.adaptiveSpacing(12),
                      ),
                    ),
                    child: Text(isAuthExpired ? 'Login Again' : 'Try Reconnecting'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      data: (data) {
        final userData = data['user'] ?? {};
        final stats = data['stats'] ?? {};
        final recentApps = data['recent_applications'] as List? ?? [];

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              _buildAmbientGlowBackground(),
              _buildBackgroundAesthetics(),
              SafeArea(
                child: RefreshIndicator(
                  onRefresh: _handleRefresh,
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  child: CenteredContent(
                    child: RepaintBoundary(
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          _buildHeaderSliver(userData),
                          SliverToBoxAdapter(child: SizedBox(height: context.adaptiveSpacing(24))),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            sliver: _buildPerformanceGrid(stats),
                          ),
                          SliverToBoxAdapter(child: SizedBox(height: context.adaptiveSpacing(32))),
                          _buildSectionHeader('Smart Tools'),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            sliver: _buildActionGrid(context),
                          ),
                          SliverToBoxAdapter(child: SizedBox(height: context.adaptiveSpacing(24))),
                          _buildSectionHeader('Recent Activity', showSeeAll: true),
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(20, 16, 20, context.isMobile ? 100 : 120),
                            sliver: _buildActivityList(recentApps),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          
              // JARVIS Floating Assistant
              Positioned(
                right: context.isMobile ? 20 : 40,
                bottom: context.isMobile ? 110 : 130,
                child: GestureDetector(
                  onTap: () => context.push('/jarvis'),
                  child: Container(
                    padding: EdgeInsets.all(context.adaptiveSpacing(12)),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(Icons.psychology, 
                               color: Colors.white, 
                               size: context.adaptiveIconSize(32)),
                  ),
                ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                 .scale(duration: 2.seconds, begin: const Offset(1, 1), end: const Offset(1.1, 1.1))
                 .shimmer(delay: 5.seconds, duration: 2.seconds),
              ),
          
              // Floating Bottom Nav
              Positioned(
                left: 0,
                right: 0,
                bottom: context.isMobile ? 30 : 40,
                child: CenteredContent(
                  maxWidth: 800,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildFloatingBottomNav(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBackgroundAesthetics() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.05),
            ),
          ).animate().fadeIn(duration: 1000.ms).scale(begin: const Offset(0.8, 0.8)),
        ),
        Positioned(
          bottom: 200,
          left: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondary.withValues(alpha: 0.03),
            ),
          ).animate().fadeIn(duration: 1200.ms).scale(begin: const Offset(0.7, 0.7)),
        ),
      ],
    );
  }

  Widget _buildAmbientGlowBackground() {
    return const Positioned.fill(
      child: RepaintBoundary(
        child: AnimatedAmbientBackground(),
      ),
    );
  }

  Widget _buildHeaderSliver(Map userData) {
    final String name = userData['full_name'] ?? 'User';
    final String? profilePic = userData['profile_pic_url'];
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning,' : hour < 17 ? 'Good afternoon,' : 'Good evening,';

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, context.adaptiveSpacing(20), 24, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: GoogleFonts.inter(
                    fontSize: context.adaptiveTextSize(14),
                    color: AppColors.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                ShaderMask(
                  shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                  child: Text(
                    name,
                    style: GoogleFonts.outfit(
                      fontSize: context.adaptiveTextSize(26),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            InkWell(
              onTap: () => context.push('/details').then((_) => ref.invalidate(dashboardProvider)),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                ),
                child: CircleAvatar(
                  radius: context.adaptiveIconSize(26),
                  backgroundColor: AppColors.surfaceHigh,
                  backgroundImage: profilePic != null ? NetworkImage(profilePic) : null,
                  child: profilePic == null ? Icon(Icons.person, color: Colors.white, size: context.adaptiveIconSize(28)) : null,
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1),
    );
  }

  Widget _buildSectionHeader(String title, {bool showSeeAll = false}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: context.adaptiveTextSize(18),
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
              ),
            ),
            if (showSeeAll)
              TextButton(
                onPressed: () => context.push('/applications').then((_) => ref.invalidate(dashboardProvider)),
                child: Text(
                  'Explore All',
                  style: GoogleFonts.inter(
                    fontSize: context.adaptiveTextSize(12),
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceGrid(Map stats) {
    return SliverGrid.count(
      crossAxisCount: context.isMobile ? 2 : 4,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: context.isMobile ? 1.6 : 1.3,
      children: [
        _buildStatTile('Total Applied', stats['total_applications']?.toString() ?? '0', Icons.send_rounded, AppColors.primary),
        _buildStatTile('Pending', stats['pending_responses']?.toString() ?? '0', Icons.hourglass_empty_rounded, AppColors.tertiary),
        _buildStatTile('Interviews', stats['interviews']?.toString() ?? '0', Icons.video_call_rounded, AppColors.success),
        _buildStatTile('Success Rate', stats['response_rate'] ?? '0%', Icons.auto_graph_rounded, AppColors.secondary),
      ],
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return GlassContainer(
      padding: EdgeInsets.all(context.adaptiveSpacing(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: context.adaptiveIconSize(14), color: color.withValues(alpha: 0.8)),
              const Spacer(),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: context.adaptiveTextSize(24),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: context.adaptiveTextSize(10),
              color: AppColors.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack);
  }

  Widget _buildActionGrid(BuildContext context) {
    final actions = [
      _ActionItem('Auto Pilot', Icons.rocket_launch, AppColors.primary, '/auto-applier'),
      _ActionItem('ATS Audit', Icons.analytics_rounded, AppColors.tertiary, '/ats'),
      _ActionItem('Resume', Icons.description_rounded, AppColors.secondary, '/resume'),
      _ActionItem('Tailor AI', Icons.auto_awesome, const Color(0xFFEC4899), '/resume-tailor'),
      _ActionItem('LinkedIn', Icons.work_history_rounded, AppColors.success, '/linkedin-opt'),
      _ActionItem('Email Agent', Icons.mail_outline_rounded, AppColors.warning, '/email-agent'),
    ];

    if (context.isMobile) {
      return SliverToBoxAdapter(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: actions.map((action) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _buildActionCard(context, action),
            )).toList(),
          ),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildActionCard(context, actions[index]),
        childCount: actions.length,
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, _ActionItem action) {
    return InkWell(
      onTap: () => context.push(action.route).then((_) => ref.invalidate(dashboardProvider)),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: context.adaptiveIconSize(64),
            height: context.adaptiveIconSize(64),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.outline.withValues(alpha: 0.3)),
              gradient: LinearGradient(
                colors: [
                  action.color.withValues(alpha: 0.1),
                  action.color.withValues(alpha: 0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(action.icon, color: action.color, size: context.adaptiveIconSize(28)),
          ),
          SizedBox(height: context.adaptiveSpacing(8)),
          Text(
            action.name,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: context.adaptiveTextSize(11),
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildActivityList(List apps) {
    if (apps.isEmpty) {
      return SliverToBoxAdapter(
        child: GlassContainer(
          padding: EdgeInsets.symmetric(vertical: context.adaptiveSpacing(40)),
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, 
                   size: context.adaptiveIconSize(40), 
                   color: AppColors.onSurface.withValues(alpha: 0.2)),
              SizedBox(height: context.adaptiveSpacing(12)),
              Text(
                'No applications yet.',
                style: TextStyle(
                  color: AppColors.onSurface.withValues(alpha: 0.4),
                  fontSize: context.adaptiveTextSize(14),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final app = apps[index];
          final title = app['job_title'] ?? app['title'] ?? 'Role';
          final company = app['company_name'] ?? app['company'] ?? 'Company';
          final status = app['status'] ?? 'Pending';
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassContainer(
              padding: EdgeInsets.all(context.adaptiveSpacing(12)),
              child: Row(
                children: [
                  Container(
                    width: context.adaptiveIconSize(48),
                    height: context.adaptiveIconSize(48),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        company[0].toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: context.adaptiveTextSize(16),
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
                          title,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold, 
                            fontSize: context.adaptiveTextSize(14),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          company,
                          style: GoogleFonts.inter(
                            fontSize: context.adaptiveTextSize(12), 
                            color: AppColors.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
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
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      status.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: context.adaptiveTextSize(9),
                        fontWeight: FontWeight.w800,
                        color: _getStatusColor(status),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: (index * 80).ms).slideX(begin: 0.05);
        },
        childCount: apps.length,
      ),
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

  Widget _buildFloatingBottomNav(BuildContext context) {
    return GlassContainer(
      padding: EdgeInsets.symmetric(
        horizontal: context.adaptiveSpacing(10), 
        vertical: context.adaptiveSpacing(8),
      ),
      borderRadius: 32.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBottomNavItem(Icons.grid_view_rounded, 'Home', true, onTap: () {}),
          _buildBottomNavItem(Icons.mail_outline_rounded, 'Inbox', false, onTap: () => context.push('/email-agent')),
          _buildBottomNavItem(Icons.auto_awesome_outlined, 'Scan', false, onTap: () => context.push('/ats')),
          _buildBottomNavItem(Icons.rocket_launch_rounded, 'Apply', false, onTap: () => context.push('/auto-applier')),
          _buildBottomNavItem(Icons.person_outline_rounded, 'Me', false, onTap: () => context.push('/settings')),
        ],
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, String label, bool isActive, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.adaptiveSpacing(16), 
          vertical: context.adaptiveSpacing(10),
        ),
        decoration: isActive ? BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(24),
        ) : null,
        child: Row(
          children: [
            Icon(icon, 
                 color: isActive ? AppColors.primary : AppColors.onSurface.withValues(alpha: 0.6), 
                 size: context.adaptiveIconSize(20)),
            if (isActive || context.isDesktop) ...[
              SizedBox(width: context.adaptiveSpacing(8)),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: context.adaptiveTextSize(12),
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionItem {
  final String name;
  final IconData icon;
  final Color color;
  final String route;

  _ActionItem(this.name, this.icon, this.color, this.route);
}
