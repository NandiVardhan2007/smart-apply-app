import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/neon_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../providers/auth_provider.dart';
import '../../../../core/utils/responsive_utils.dart';


class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    setState(() => _isLoading = true);
    try {
      final response = await apiClient.post(ApiConstants.login, data: {
        'email': _emailController.text,
        'password': _passwordController.text,
      });

      if (response.statusCode == 200) {
        final token = response.data['access_token'];
        final isProfileCompleted = response.data['is_profile_completed'] ?? false;
        
        // Update global auth state
        await ref.read(authProvider.notifier).login(token);
        
        if (mounted) {
          if (!isProfileCompleted) {
            // Profile incomplete, redirect to details (GoRouter might have already 
            // redirected to /, so we push details on top or handle in router)
            context.push('/details');
          }
          // Note: If profile IS completed, AuthProvider update triggers 
          // redirect to / via routerProvider logic.
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.1),
              ),
            ),
          ),
          
          SafeArea(
            child: CenteredContent(
              maxWidth: 500,
              child: Padding(
                padding: EdgeInsets.all(context.adaptiveSpacing(24)),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: context.adaptiveSpacing(60)),
                      ShaderMask(
                        shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                        child: Text(
                          'Welcome Back',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: Colors.white,
                            fontSize: context.adaptiveTextSize(40),
                          ),
                        ),
                      ),
                      SizedBox(height: context.adaptiveSpacing(8)),
                      Text(
                        'Log in to your Smart Apply assistant',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: context.adaptiveTextSize(16),
                        ),
                      ),
                      SizedBox(height: context.adaptiveSpacing(40)),
                      GlassContainer(
                        padding: EdgeInsets.all(context.adaptiveSpacing(20)),
                        child: Column(
                          children: [
                            AppTextField(
                              controller: _emailController,
                              label: 'Email Address',
                              hint: 'name@example.com',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1),
                            SizedBox(height: context.adaptiveSpacing(20)),
                            AppTextField(
                              controller: _passwordController,
                              label: 'Password',
                              hint: '••••••••',
                              isPassword: _obscurePassword,
                              prefixIcon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: AppColors.outline,
                                  size: context.adaptiveIconSize(20),
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1),
                            SizedBox(height: context.adaptiveSpacing(16)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                      width: context.adaptiveSpacing(24),
                                      height: context.adaptiveSpacing(24),
                                      child: Checkbox(
                                        value: _rememberMe,
                                        onChanged: (v) => setState(() => _rememberMe = v!),
                                        side: const BorderSide(color: AppColors.outline),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      ),
                                    ),
                                    SizedBox(width: context.adaptiveSpacing(8)),
                                    Text('Remember me', style: TextStyle(fontSize: context.adaptiveTextSize(14))),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () => context.push('/reset-password'),
                                  child: Text(
                                    'Forgot Password?', 
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: context.adaptiveTextSize(14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: context.adaptiveSpacing(32)),
                            NeonButton(
                              text: 'Sign In',
                              isLoading: _isLoading,
                              onPressed: _handleLogin,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: context.adaptiveSpacing(40)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: TextStyle(fontSize: context.adaptiveTextSize(14)),
                          ),
                          TextButton(
                            onPressed: () => context.push('/signup'),
                            child: Text(
                              'Sign Up', 
                              style: TextStyle(
                                color: AppColors.primary, 
                                fontWeight: FontWeight.bold,
                                fontSize: context.adaptiveTextSize(14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
