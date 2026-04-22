import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/login/login_screen.dart';
import '../features/auth/signup/signup_screen.dart';
import '../features/auth/signup/otp_verification_screen.dart';
import '../features/auth/reset_password/reset_password_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/auto_applier/auto_applier_screen.dart';
import '../features/personal_details/personal_details_screen.dart';
import '../features/ats_checking/ats_checking_screen.dart';
import '../features/linkedin_optimizing/linkedin_optimizing_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/jarvis/jarvis_chat_screen.dart';
import '../features/resume/my_resume_screen.dart';
import '../features/resume_builder/resume_tailor_screen.dart';
import '../features/resume_builder/pdf_preview_screen.dart';
import '../features/applications/applications_screen.dart';
import '../features/email_agent/screens/email_agent_screen.dart';
import '../features/auth/providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthRefreshListenable(ref),
    redirect: (context, state) {
      final status = authState.status;
      
      // If still initializing, show nothing or a splash (we'll stay on / for now)
      if (status == AuthStatus.initial) return null;

      final loggingIn = state.matchedLocation == '/login' || 
                        state.matchedLocation == '/signup' || 
                        state.matchedLocation == '/reset-password' ||
                        state.matchedLocation == '/otp-verification';

      if (status == AuthStatus.unauthenticated) {
        return loggingIn ? null : '/login';
      }

      if (status == AuthStatus.authenticated && loggingIn) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/otp-verification',
        builder: (context, state) {
          final email = state.extra as String;
          return OtpVerificationScreen(email: email);
        },
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/auto-applier',
        builder: (context, state) => const AutoApplierScreen(),
      ),
      GoRoute(
        path: '/details',
        builder: (context, state) => const PersonalDetailsScreen(),
      ),
      GoRoute(
        path: '/ats',
        builder: (context, state) => const AtsCheckingScreen(),
      ),
      GoRoute(
        path: '/linkedin-opt',
        builder: (context, state) => const LinkedinOptimizingScreen(),
      ),
      GoRoute(
        path: '/jarvis',
        builder: (context, state) => const JarvisChatScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/resume',
        builder: (context, state) => const MyResumeScreen(),
      ),
      GoRoute(
        path: '/applications',
        builder: (context, state) => const ApplicationsScreen(),
      ),
      GoRoute(
        path: '/resume-tailor',
        builder: (context, state) => const ResumeTailorScreen(),
      ),
      GoRoute(
        path: '/email-agent',
        builder: (context, state) => const EmailAgentScreen(),
      ),
      GoRoute(
        path: '/pdf-preview',
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>;
          return PdfPreviewScreen(
            resumeId: extras['resumeId'] as String,
            title: extras['title'] as String,
          );
        },
      ),
    ],
  );
});

// A listenable that triggers GoRouter refresh when auth state changes
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(Ref ref) {
    ref.listen(authProvider, (previous, next) {
      if (previous?.status != next.status) {
        notifyListeners();
      }
    });
  }
}
