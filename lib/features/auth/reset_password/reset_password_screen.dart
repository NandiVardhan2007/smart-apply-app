import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/neon_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';

enum ResetStep { email, otpAndNewPassword, success }

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isLoading = false;
  ResetStep _currentStep = ResetStep.email;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _handleRequestOTP() async {
    if (_emailController.text.isEmpty) {
      _showError('Please enter your email address');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await apiClient.post(ApiConstants.forgotPassword, data: {
        'email': _emailController.text,
      });

      if (response.statusCode == 200) {
        setState(() {
          _currentStep = ResetStep.otpAndNewPassword;
        });
        _showSuccess('OTP sent to your email');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleResetPassword() async {
    if (_otpController.text.isEmpty || _newPasswordController.text.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await apiClient.post(ApiConstants.resetPassword, data: {
        'email': _emailController.text,
        'otp': _otpController.text,
        'new_password': _newPasswordController.text,
      });

      if (response.statusCode == 200) {
        setState(() {
          _currentStep = ResetStep.success;
        });
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: 100,
            right: -20,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.tertiary.withValues(alpha: 0.08),
              ),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      _getTitle(),
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _getSubtitle(),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 48),
                    _buildStepContent(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTitle() {
    switch (_currentStep) {
      case ResetStep.email:
        return 'Reset Password';
      case ResetStep.otpAndNewPassword:
        return 'Verify OTP';
      case ResetStep.success:
        return 'Password Changed';
    }
  }

  String _getSubtitle() {
    switch (_currentStep) {
      case ResetStep.email:
        return 'Enter your email address and we\'ll send you a code to reset your password.';
      case ResetStep.otpAndNewPassword:
        return 'Enter the 6-digit code sent to your email and your new password.';
      case ResetStep.success:
        return 'Your password has been reset successfully. You can now login with your new password.';
    }
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case ResetStep.email:
        return GlassContainer(
          child: Column(
            children: [
              AppTextField(
                controller: _emailController,
                label: 'Email Address',
                hint: 'name@example.com',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 32),
              NeonButton(
                text: 'Send Reset Code',
                isLoading: _isLoading,
                onPressed: _handleRequestOTP,
              ),
            ],
          ),
        );
      case ResetStep.otpAndNewPassword:
        return GlassContainer(
          child: Column(
            children: [
              AppTextField(
                controller: _otpController,
                label: 'Verification Code',
                hint: '123456',
                prefixIcon: Icons.security_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              AppTextField(
                controller: _newPasswordController,
                label: 'New Password',
                hint: '••••••••',
                isPassword: _obscurePassword,
                prefixIcon: Icons.lock_outline,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.outline,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 32),
              NeonButton(
                text: 'Reset Password',
                isLoading: _isLoading,
                onPressed: _handleResetPassword,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _currentStep = ResetStep.email),
                child: const Text('Change Email', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        );
      case ResetStep.success:
        return GlassContainer(
          child: Column(
            children: [
              const Icon(Icons.check_circle_outline, size: 64, color: AppColors.primary),
              const SizedBox(height: 24),
              const Text(
                'Success!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.onSurface),
              ),
              const SizedBox(height: 48),
              NeonButton(
                text: 'Back to Login',
                onPressed: () => context.go('/login'),
              ),
            ],
          ),
        );
    }
  }
}
