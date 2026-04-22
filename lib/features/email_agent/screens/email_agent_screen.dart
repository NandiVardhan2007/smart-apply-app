import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/animated_ambient_background.dart';
import '../providers/email_agent_provider.dart';

class EmailAgentScreen extends ConsumerStatefulWidget {
  const EmailAgentScreen({super.key});

  @override
  ConsumerState<EmailAgentScreen> createState() => _EmailAgentScreenState();
}

class _EmailAgentScreenState extends ConsumerState<EmailAgentScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(emailAgentProvider.notifier).init());
  }


  void _showDraftResultDialog(String draft, String threadId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.primary),
            const SizedBox(width: 12),
            Text('Jarvis Draft', style: GoogleFonts.outfit()),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jarvis has prepared this response. Review it before sending.',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                draft,
                style: GoogleFonts.inter(fontSize: 14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (threadId.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () async {
                final success = await ref.read(emailAgentProvider.notifier).sendReply(threadId, draft);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Reply sent successfully!' : 'Failed to send reply.'),
                      backgroundColor: success ? AppColors.success : AppColors.error,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Send Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
            ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: draft));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Draft copied to clipboard')),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConnect() async {
    final url = await ref.read(emailAgentProvider.notifier).getAuthUrl();
    if (url != null) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Authorize in browser, then tap "I have connected"')),
           );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch browser. URL: $url')),
          );
        }
      }
    } else {
      final error = ref.read(emailAgentProvider).error;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error ?? 'Failed to get authorization URL')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(emailAgentProvider);

    ref.listen<EmailAgentState>(emailAgentProvider, (previous, next) {
      if (previous?.data?['last_draft'] != next.data?['last_draft'] &&
          next.data?['last_draft'] != null) {
        _showDraftResultDialog(
          next.data!['last_draft'],
          next.lastThreadId ?? '',
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedAmbientBackground()),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: state.isLoading 
                    ? _buildLoadingState() 
                    : (!state.isAuthorized ? _buildConnectState() : _buildDataState(state)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 8),
          Text(
            'Email Intelligence',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.security, size: 14, color: AppColors.success),
                const SizedBox(width: 4),
                Text(
                  'Encrypted',
                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
     return Center(
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           const CircularProgressIndicator(color: AppColors.primary),
           const SizedBox(height: 24),
           Text(
             'Scanning your connected inbox...',
             style: GoogleFonts.inter(color: AppColors.onSurface.withValues(alpha: 0.7)),
           ).animate(onPlay: (c) => c.repeat()).fadeIn(duration: 1.seconds).then().fadeOut(duration: 1.seconds),
         ],
       ),
     );
  }

  Widget _buildConnectState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mail_lock_rounded, size: 64, color: AppColors.primary),
            ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 32),
            Text(
              'Disconnected inbox',
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Connect your Gmail to let the Email Intelligence Agent monitor and draft replies for you.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: _handleConnect,
              icon: const Icon(Icons.login),
              label: const Text('Connect Google Client'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => ref.read(emailAgentProvider.notifier).markAuthorized(),
              child: const Text('I have already authorized', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataState(EmailAgentState state) {
    final emails = state.data?['important_emails'] as List? ?? [];
    final notes = state.data?['notes_for_user'] ?? '';
    final recentEmails = state.data?['recent_emails'] as List? ?? [];

    return RefreshIndicator(
      onRefresh: () => ref.read(emailAgentProvider.notifier).scanEmails(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (emails.isNotEmpty) ...[
            _buildInfoCard(notes),
            const SizedBox(height: 24),
            Text(
              'Important Findings',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...emails.asMap().entries.map((entry) => _buildEmailCard(entry.value, entry.key)),
            const SizedBox(height: 32),
          ],
          
          if (emails.isEmpty) ...[
             const SizedBox(height: 40),
             const Center(child: Icon(Icons.done_all_rounded, size: 60, color: AppColors.success)),
             const SizedBox(height: 16),
             Center(
               child: Text(
                 'AI Analysis: Inbox Zero!',
                 style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
               ),
             ),
             Center(
               child: Text(
                 'No urgent recruiter action items found.',
                 style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.6)),
               ),
             ),
             const SizedBox(height: 40),
          ],
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity (${recentEmails.length})',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (emails.isEmpty) 
                IconButton(
                  onPressed: () => ref.read(emailAgentProvider.notifier).scanEmails(),
                  icon: const Icon(Icons.refresh, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentEmails.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text('No recent emails found.', style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.4))),
              ),
            ),
          ...recentEmails.map((email) => _buildRecentEmailCard(email)),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildRecentEmailCard(Map email) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    email['sender'] ?? 'Unknown',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  email['date']?.toString().split(',').first ?? '',
                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.onSurface.withValues(alpha: 0.5)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              email['subject'] ?? 'No Subject',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              email['snippet'] ?? '',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurface.withValues(alpha: 0.6)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final Uri emailLaunchUri = Uri(
                        scheme: 'mailto',
                        path: email['sender']?.toString().split('<').last.split('>').first ?? '',
                        query: 'subject=Re: ${email['subject']}',
                      );
                      if (await canLaunchUrl(emailLaunchUri)) {
                        await launchUrl(emailLaunchUri);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Text('Manual Reply', style: GoogleFonts.inter(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final mailContext = "From: ${email['sender']}\nSubject: ${email['subject']}\nContent: ${email['snippet']}";
                      final threadId = email['threadId']?.toString() ?? email['id']?.toString() ?? '';
                      _showDraftInstructionSheet(context, threadId, mailContext);
                    },
                    icon: const Icon(Icons.auto_awesome, size: 14),
                    label: Text('Jarvis Draft', style: GoogleFonts.inter(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDraftInstructionSheet(BuildContext context, String threadId, String mailContext) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Draft with Jarvis', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Instruction (optional):', style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurface.withValues(alpha: 0.6))),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'e.g., Accept the invite for Tuesday morning...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ref.read(emailAgentProvider.notifier).generateDraft(threadId, mailContext, controller.text);
                  },
                  child: const Text('Generate Professional Draft'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String notes) {
    if (notes.isEmpty) return const SizedBox.shrink();
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              notes,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurface.withValues(alpha: 0.8)),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildEmailCard(Map email, int index) {
    final priority = email['priority']?.toString().toLowerCase() ?? 'normal';
    final color = priority == 'urgent' ? AppColors.error : (priority == 'important' ? AppColors.warning : AppColors.primary);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    priority.toUpperCase(),
                    style: GoogleFonts.robotoMono(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.more_horiz, color: Colors.white54),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              email['subject'] ?? 'No Subject',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'From: ${email['sender']}',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurface.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 16),
            Text(
              email['summary'] ?? '',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recommened Action:',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email['recommended_action'] ?? '',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.outline.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Dismiss', style: TextStyle(color: Colors.white70)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final threadId = email['thread_id']?.toString() ?? '';
                      final mailContext = "From: ${email['sender']}\nSubject: ${email['subject']}\nSummary: ${email['summary']}";
                      _showDraftInstructionSheet(context, threadId, mailContext);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Draft Reply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.05);
  }
}
