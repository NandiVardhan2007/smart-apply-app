import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/glass_container.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../auth/providers/auth_provider.dart';

import '../../core/utils/responsive_utils.dart';


class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  
  bool _notificationsEnabled = true;
  bool _autoApplyEnabled = false;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    try {
      final response = await apiClient.get(ApiConstants.profile);
      if (response.statusCode == 200) {
        setState(() {
          _userData = response.data;
        });
      }
    } catch (e) {
      debugPrint('Error fetching settings profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Logout', style: TextStyle(color: AppColors.primary)),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Logout', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Clear global auth state - this will trigger redirect to /login via router logic
      await ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(fontSize: context.adaptiveTextSize(20))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _fetchProfileData,
            icon: Icon(Icons.refresh, color: AppColors.primary, size: context.adaptiveIconSize(24)),
          ),
        ],
      ),
      body: CenteredContent(
        maxWidth: 800,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.adaptiveSpacing(24)),
          child: Column(
            children: [
              _buildProfileCard(),
              SizedBox(height: context.adaptiveSpacing(32)),
              _buildSettingsSection('Account', [
                _buildActionTile(
                  'Personal Details', 
                  Icons.person_outline, 
                  () => context.push('/details').then((_) => _fetchProfileData()),
                  subtitle: 'Name, email, phone, and professional links',
                ),
                _buildActionTile(
                  'My Resume', 
                  Icons.description_outlined, 
                  () => context.push('/resume'),
                  subtitle: 'Manage your primary resume PDF',
                ),
                _buildActionTile('Security', Icons.lock_outline, () {}),
              ]),
              SizedBox(height: context.adaptiveSpacing(24)),
              _buildSettingsSection('Preferences', [
                _buildToggleTile(
                  'Push Notifications', 
                  _notificationsEnabled, 
                  (v) => setState(() => _notificationsEnabled = v), 
                  Icons.notifications_none_outlined,
                ),
                _buildToggleTile(
                  'Enable Auto-Apply', 
                  _autoApplyEnabled, 
                  (v) => setState(() => _autoApplyEnabled = v), 
                  Icons.rocket_launch_outlined,
                ),
              ]),
              SizedBox(height: context.adaptiveSpacing(24)),
              _buildSettingsSection('Support & About', [
                _buildActionTile('Help Center', Icons.help_outline, () {}),
                _buildActionTile('Privacy Policy', Icons.privacy_tip_outlined, () {}),
                _buildActionTile('App Version', Icons.info_outline, () {}, trailing: Text('1.0.0', style: TextStyle(fontSize: context.adaptiveTextSize(12), color: AppColors.outline))),
              ]),
              SizedBox(height: context.adaptiveSpacing(48)),
              _buildLogoutButton(),
              SizedBox(height: context.adaptiveSpacing(40)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final String fullName = _userData?['full_name'] ?? 'SmartUser';
    final String email = _userData?['email'] ?? '';
    final String? profilePic = _userData?['profile_pic_url'];

    return GlassContainer(
      padding: EdgeInsets.all(context.adaptiveSpacing(16)),
      child: Row(
        children: [
          Container(
            width: context.adaptiveSpacing(70),
            height: context.adaptiveSpacing(70),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2),
              image: profilePic != null
                  ? DecorationImage(image: NetworkImage(profilePic), fit: BoxFit.cover)
                  : null,
            ),
            child: profilePic == null
                ? Icon(Icons.person, size: context.adaptiveIconSize(35), color: AppColors.primary)
                : null,
          ),
          SizedBox(width: context.adaptiveSpacing(20)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName, 
                  style: TextStyle(
                    fontSize: context.adaptiveTextSize(20), 
                    fontWeight: FontWeight.bold, 
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email, 
                  style: TextStyle(
                    fontSize: context.adaptiveTextSize(14), 
                    color: AppColors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.push('/details').then((_) => _fetchProfileData()),
            icon: Icon(Icons.arrow_forward_ios, size: context.adaptiveIconSize(16), color: AppColors.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 8, bottom: context.adaptiveSpacing(12)),
          child: Text(
            title.toUpperCase(), 
            style: TextStyle(
              fontSize: context.adaptiveTextSize(12), 
              fontWeight: FontWeight.w800, 
              color: AppColors.primary, 
              letterSpacing: 1.2,
            ),
          ),
        ),
        GlassContainer(
          padding: EdgeInsets.zero,
          child: Column(
            children: children.asMap().entries.map((entry) {
              final idx = entry.key;
              final widget = entry.value;
              return Column(
                children: [
                  widget,
                  if (idx < children.length - 1)
                    Divider(height: 1, color: AppColors.outline.withValues(alpha: 0.1), indent: context.adaptiveSpacing(56)),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleTile(String label, bool value, ValueChanged<bool> onChanged, IconData icon) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: context.adaptiveSpacing(20), vertical: context.adaptiveSpacing(4)),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: context.adaptiveIconSize(20), color: AppColors.primary),
      ),
      title: Text(label, style: TextStyle(fontSize: context.adaptiveTextSize(15), fontWeight: FontWeight.w500)),
      trailing: Switch(
        value: value, 
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
        activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildActionTile(String label, IconData icon, VoidCallback onTap, {String? subtitle, Widget? trailing, Color? color}) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: context.adaptiveSpacing(20), vertical: context.adaptiveSpacing(4)),
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: context.adaptiveIconSize(20), color: color ?? AppColors.primary),
      ),
      title: Text(label, style: TextStyle(fontSize: context.adaptiveTextSize(15), fontWeight: FontWeight.w500, color: color)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: context.adaptiveTextSize(12), color: AppColors.onSurface.withValues(alpha: 0.5))) : null,
      trailing: trailing ?? Icon(Icons.arrow_forward_ios, size: context.adaptiveIconSize(14), color: AppColors.outline),
    );
  }

  Widget _buildLogoutButton() {
    return NeonButton(
      text: 'Log Out',
      onPressed: _handleLogout,
    );
  }
}

class NeonButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;

  const NeonButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: context.adaptiveSpacing(18)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.8),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  height: context.adaptiveSpacing(20),
                  width: context.adaptiveSpacing(20),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  text,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: context.adaptiveTextSize(16),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
        ),
      ),
    );
  }
}
