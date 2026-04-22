import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/glass_container.dart';
import '../../shared/widgets/neon_button.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart' as dio;
import 'package:google_fonts/google_fonts.dart';
import '../dashboard/providers/dashboard_provider.dart';
import '../../core/utils/responsive_utils.dart';



class PersonalDetailsScreen extends ConsumerStatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  ConsumerState<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends ConsumerState<PersonalDetailsScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();
  final _educationController = TextEditingController();
  final _experienceController = TextEditingController();
  final _skillsController = TextEditingController();
  final _portfolioController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _githubController = TextEditingController();
  final _searchTermsController = TextEditingController();
  final _badWordsController = TextEditingController();
  
  // Advanced Job Profile Controllers
  String _primaryField = 'Engineering';
  bool _isGraduationCompleted = false;
  final _graduationYearController = TextEditingController();
  final _noticePeriodController = TextEditingController();
  final _currentCtcController = TextEditingController();
  final _expectedCtcController = TextEditingController();
  String _gender = 'Male';
  bool _isAuthorizedToWork = true;
  bool _requiresSponsorship = false;
  bool _willingToRelocate = true;
  String _highestDegree = "Bachelor's";
  final _workExpYearsController = TextEditingController();
  final _specializationController = TextEditingController();
  
  bool _isLoading = true;
  bool _isAiParsing = false;
  bool _isGeneratingTerms = false;
  bool _isUploadingPhoto = false;
  String? _profilePicUrl;
  double _completeness = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDetails();
    _setupListeners();
  }

  void _setupListeners() {
    for (var controller in [
      _firstNameController, _lastNameController, _emailController, 
      _phoneController, _cityController, _stateController,
      _countryController, _educationController,
      _experienceController, _skillsController, _portfolioController,
      _linkedinController, _githubController,
      _graduationYearController, _noticePeriodController,
      _currentCtcController, _expectedCtcController, _workExpYearsController,
      _searchTermsController, _badWordsController
    ]) {
      controller.addListener(_calculateCompleteness);
    }
  }

  void _calculateCompleteness() {
    int totalFields = 20;
    int filledFields = 0;
    for (var controller in [
      _firstNameController, _lastNameController, _emailController, 
      _phoneController, _cityController, _stateController,
      _countryController, _educationController,
      _experienceController, _skillsController, _portfolioController,
      _linkedinController, _githubController,
      _graduationYearController, _noticePeriodController,
      _currentCtcController, _expectedCtcController, _workExpYearsController,
      _searchTermsController, _badWordsController
    ]) {
      if (controller.text.isNotEmpty) filledFields++;
    }
    setState(() => _completeness = filledFields / totalFields);
  }

  Future<void> _loadDetails() async {
    try {
      final response = await apiClient.get(ApiConstants.profile);
      if (response.statusCode == 200) {
        final data = response.data;
        _firstNameController.text = data['first_name'] ?? '';
        _lastNameController.text = data['last_name'] ?? '';
        _emailController.text = data['email'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _cityController.text = data['current_city'] ?? '';
        _stateController.text = data['state'] ?? '';
        _countryController.text = data['country'] ?? '';
        _educationController.text = data['education'] ?? '';
        _experienceController.text = data['experience'] ?? '';
        _skillsController.text = data['skills'] ?? '';
        _portfolioController.text = data['portfolio_url'] ?? '';
        _linkedinController.text = data['linkedin_url'] ?? '';
        _githubController.text = data['github_url'] ?? '';
        
        // Advanced Fields
        _primaryField = data['primary_field'] ?? 'Engineering';
        _isGraduationCompleted = data['is_engineering_completed'] ?? false;
        _graduationYearController.text = (data['graduation_year'] ?? '').toString();
        _noticePeriodController.text = (data['notice_period_days'] ?? '').toString();
        _currentCtcController.text = (data['current_ctc'] ?? '').toString();
        _expectedCtcController.text = (data['expected_ctc'] ?? '').toString();
        _gender = data['gender'] ?? 'Male';
        _isAuthorizedToWork = data['is_authorized_to_work'] ?? true;
        _requiresSponsorship = data['requires_sponsorship'] ?? false;
        _willingToRelocate = data['willing_to_relocate'] ?? true;
        _highestDegree = data['highest_degree'] ?? "Bachelor's";
        _workExpYearsController.text = (data['work_experience_years'] ?? '').toString();
        _specializationController.text = data['experience'] ?? '';
        _searchTermsController.text = data['search_terms'] ?? '';
        _badWordsController.text = data['bad_words'] ?? '';

        setState(() {
          _profilePicUrl = data['profile_pic_url'];
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      setState(() => _isLoading = false);
      _calculateCompleteness();
    }
  }

  Future<void> _saveDetails() async {
    setState(() => _isLoading = true);
    try {
      final data = {
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'current_city': _cityController.text,
        'state': _stateController.text,
        'country': _countryController.text,
        'education': _educationController.text,
        'experience': _experienceController.text,
        'skills': _skillsController.text,
        'portfolio_url': _portfolioController.text,
        'linkedin_url': _linkedinController.text,
        'github_url': _githubController.text,
        
        // Advanced Fields
        'primary_field': _primaryField,
        'is_engineering_completed': _isGraduationCompleted,
        'graduation_year': int.tryParse(_graduationYearController.text),
        'notice_period_days': int.tryParse(_noticePeriodController.text),
        'current_ctc': double.tryParse(_currentCtcController.text),
        'expected_ctc': double.tryParse(_expectedCtcController.text),
        'gender': _gender,
        'is_authorized_to_work': _isAuthorizedToWork,
        'requires_sponsorship': _requiresSponsorship,
        'willing_to_relocate': _willingToRelocate,
        'highest_degree': _highestDegree,
        'work_experience_years': double.tryParse(_workExpYearsController.text),
        'search_terms': _searchTermsController.text,
        'bad_words': _badWordsController.text,
      };

      final response = await apiClient.put(
        ApiConstants.profile,
        data: data,
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile saved successfully!')),
          );
          // Refresh global dashboard
          ref.invalidate(dashboardProvider);
          // New: Redirect to dashboard after completing profile
          context.go('/');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result == null) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final file = result.files.first;
      late List<int> bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else {
        bytes = await File(file.path!).readAsBytes();
      }

      final formData = dio.FormData.fromMap({
        'file': dio.MultipartFile.fromBytes(
          bytes,
          filename: file.name,
        ),
      });

      final response = await apiClient.post(
        ApiConstants.uploadAvatar,
        data: formData,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final newUrl = response.data['url'];
        debugPrint('DEBUG: Profile photo upload success. New URL: $newUrl');
        setState(() {
          _profilePicUrl = newUrl;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _pickAndParseResume() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null) return;

    setState(() => _isAiParsing = true);

    try {
      final file = result.files.first;
      
      // Handle different platforms
      late List<int> bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else {
        bytes = await File(file.path!).readAsBytes();
      }

      final response = await apiClient.post(
        ApiConstants.parseResume,
        data: dio.FormData.fromMap({
          'file': dio.MultipartFile.fromBytes(bytes, filename: file.name),
        }),
      );

      // Also upload the resume to storage using a NEW FormData instance
      await apiClient.post(
        ApiConstants.uploadResume,
        data: dio.FormData.fromMap({
          'file': dio.MultipartFile.fromBytes(bytes, filename: file.name),
        }),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        debugPrint('DEBUG: Received parsed data: $data');
        setState(() {
          _firstNameController.text = data['firstName'] ?? data['first_name'] ?? '';
          _lastNameController.text = data['lastName'] ?? data['last_name'] ?? '';
          _emailController.text = data['email'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _cityController.text = data['current_city'] ?? '';
          _stateController.text = data['state'] ?? '';
          _countryController.text = data['country'] ?? '';
          _educationController.text = data['education'] ?? '';
          _experienceController.text = data['experience'] ?? '';
          _skillsController.text = data['skills'] ?? '';
          _portfolioController.text = data['portfolioUrl'] ?? '';
          _linkedinController.text = data['linkedinUrl'] ?? '';
          _githubController.text = data['githubUrl'] ?? '';
        });
        
        _calculateCompleteness();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI successfully parsed your resume!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI Parsing Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAiParsing = false);
    }
  }

  Future<void> _generateAutomationTerms() async {
    setState(() => _isGeneratingTerms = true);
    try {
      final response = await apiClient.post(ApiConstants.generateAutomationTerms);
      if (response.statusCode == 200) {
        final data = response.data;
        setState(() {
          _searchTermsController.text = data['search_terms'] ?? '';
          _badWordsController.text = data['bad_words'] ?? '';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI generated search keywords and exclusions!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI Generation Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingTerms = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Personal Details', 
          style: TextStyle(fontSize: context.adaptiveTextSize(18)),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: context.adaptiveIconSize(20)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: CenteredContent(
        maxWidth: 800,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.adaptiveSpacing(24)),
          child: Column(
            children: [
              _buildProfilePhoto(),
              SizedBox(height: context.adaptiveSpacing(24)),
              _buildAiAutofillCard(),
              SizedBox(height: context.adaptiveSpacing(24)),
              _buildCompletenessProgress(),
              SizedBox(height: context.adaptiveSpacing(32)),
              _buildSection('General Information', [
                AppTextField(controller: _firstNameController, label: 'First Name', hint: 'John'),
                SizedBox(height: context.adaptiveSpacing(16)),
                AppTextField(controller: _lastNameController, label: 'Last Name', hint: 'Doe'),
                SizedBox(height: context.adaptiveSpacing(16)),
                AppTextField(controller: _emailController, label: 'Email', hint: 'john@example.com', keyboardType: TextInputType.emailAddress),
                SizedBox(height: context.adaptiveSpacing(16)),
                AppTextField(controller: _phoneController, label: 'Phone', hint: '+1 234 567 890', keyboardType: TextInputType.phone),
                SizedBox(height: context.adaptiveSpacing(16)),
                Row(
                  children: [
                    Expanded(child: AppTextField(controller: _cityController, label: 'City', hint: 'London')),
                    SizedBox(width: context.adaptiveSpacing(16)),
                    Expanded(child: AppTextField(controller: _stateController, label: 'State', hint: 'London')),
                  ],
                ),
                SizedBox(height: context.adaptiveSpacing(16)),
                AppTextField(controller: _countryController, label: 'Country', hint: 'United Kingdom'),
              ]),
              SizedBox(height: context.adaptiveSpacing(24)),
              _buildSection('Professional Bio', [
                AppTextField(controller: _educationController, label: 'Education', hint: 'B.S. Computer Science'),
                SizedBox(height: context.adaptiveSpacing(16)),
                AppTextField(controller: _experienceController, label: 'Work Experience', hint: '5 years Flutter Developer'),
                SizedBox(height: context.adaptiveSpacing(16)),
                AppTextField(controller: _skillsController, label: 'Skills', hint: 'Flutter, Dart, Firebase, AI'),
              ]),
              SizedBox(height: context.adaptiveSpacing(24)),
              _buildSection('Social & Professional Links', [
                AppTextField(controller: _githubController, label: 'GitHub Profile', hint: 'https://github.com/username'),
              ]),
              SizedBox(height: context.adaptiveSpacing(24)),
              _buildSection('Application Specific Data (Auto-Applier)', [
                _buildDropdown('Primary Background', _primaryField, ["Engineering", "Management", "Others"], (v) => setState(() => _primaryField = v!)),
                SizedBox(height: context.adaptiveSpacing(16)),
                _buildSwitchTile(
                  _primaryField == 'Engineering' ? 'B.Tech/BE Completed?' : 'Degree Completed?', 
                  _isGraduationCompleted, 
                  (v) => setState(() => _isGraduationCompleted = v)
                ),
                if (_primaryField == 'Management') ...[
                  SizedBox(height: context.adaptiveSpacing(16)),
                  _buildSwitchTile('Post-Graduation (MBA) Completed?', _isGraduationCompleted, (v) => setState(() => _isGraduationCompleted = v)),
                ],
                SizedBox(height: context.adaptiveSpacing(16)),
                Row(
                  children: [
                    Expanded(child: AppTextField(controller: _graduationYearController, label: 'Graduation Year', hint: '2024', keyboardType: TextInputType.number)),
                    SizedBox(width: context.adaptiveSpacing(16)),
                    Expanded(child: AppTextField(controller: _workExpYearsController, label: 'Years of Exp', hint: '2.5', keyboardType: TextInputType.number)),
                  ],
                ),
                SizedBox(height: context.adaptiveSpacing(16)),
                _buildDropdown('Highest Degree', _highestDegree, ["Bachelor's", "Master's", "PhD", "Diploma"], (v) => setState(() => _highestDegree = v!)),
                SizedBox(height: context.adaptiveSpacing(16)),
                Row(
                  children: [
                    Expanded(child: AppTextField(controller: _currentCtcController, label: 'Current CTC', hint: '1200000', keyboardType: TextInputType.number)),
                    SizedBox(width: context.adaptiveSpacing(16)),
                    Expanded(child: AppTextField(controller: _expectedCtcController, label: 'Expected CTC', hint: '1800000', keyboardType: TextInputType.number)),
                  ],
                ),
                SizedBox(height: context.adaptiveSpacing(16)),
                AppTextField(controller: _noticePeriodController, label: 'Notice Period (Days)', hint: '30', keyboardType: TextInputType.number),
                SizedBox(height: context.adaptiveSpacing(16)),
                _buildDropdown('Gender', _gender, ["Male", "Female", "Other", "Prefer not to say"], (v) => setState(() => _gender = v!)),
                SizedBox(height: context.adaptiveSpacing(16)),
                _buildSwitchTile('Authorized to work?', _isAuthorizedToWork, (v) => setState(() => _isAuthorizedToWork = v)),
                _buildSwitchTile('Requires Sponsorship?', _requiresSponsorship, (v) => setState(() => _requiresSponsorship = v)),
                _buildSwitchTile('Willing to Relocate?', _willingToRelocate, (v) => setState(() => _willingToRelocate = v)),
              ]),
              SizedBox(height: context.adaptiveSpacing(24)),
              _buildAutomationSearchSection(),
              SizedBox(height: context.adaptiveSpacing(48)),
              NeonButton(text: 'Save Details', onPressed: _saveDetails),
              SizedBox(height: context.adaptiveSpacing(24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutomationSearchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Automation Search Settings',
              style: GoogleFonts.outfit(
                fontSize: context.adaptiveTextSize(18),
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: _isGeneratingTerms ? null : _generateAutomationTerms,
              icon: _isGeneratingTerms 
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                  : const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
              label: Text(
                'AI Generate', 
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: context.adaptiveTextSize(12))
              ),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        SizedBox(height: context.adaptiveSpacing(8)),
        Text(
          'These terms help the AI pilot find and filter relevant jobs.',
          style: TextStyle(fontSize: context.adaptiveTextSize(12), color: Colors.white60),
        ),
        SizedBox(height: context.adaptiveSpacing(16)),
        GlassContainer(
          padding: EdgeInsets.all(context.adaptiveSpacing(16)),
          child: Column(
            children: [
              AppTextField(
                controller: _searchTermsController, 
                label: 'Search Terms (Keywords)', 
                hint: 'Software Engineer, Flutter, Dart, Remote',
                maxLines: 2,
              ),
              SizedBox(height: context.adaptiveSpacing(16)),
              AppTextField(
                controller: _badWordsController, 
                label: 'Excluded Keywords (Bad Words)', 
                hint: 'Intern, Senior, Manager, Java, PHP',
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfilePhoto() {
    return Center(
      child: Stack(
        children: [
          Container(
            width: context.adaptiveSpacing(120),
            height: context.adaptiveSpacing(120),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
              image: _profilePicUrl != null
                  ? DecorationImage(image: NetworkImage(_profilePicUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: _profilePicUrl == null
                ? Icon(Icons.person, size: context.adaptiveIconSize(60), color: AppColors.onSurface)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
              child: Container(
                padding: EdgeInsets.all(context.adaptiveSpacing(8)),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: _isUploadingPhoto
                    ? SizedBox(
                        width: context.adaptiveIconSize(20),
                        height: context.adaptiveIconSize(20),
                        child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(Icons.camera_alt, color: Colors.white, size: context.adaptiveIconSize(20)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletenessProgress() {
    return GlassContainer(
      padding: EdgeInsets.all(context.adaptiveSpacing(16)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile Completeness', 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: context.adaptiveTextSize(14)),
                ),
                SizedBox(height: context.adaptiveSpacing(8)),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _completeness,
                    backgroundColor: AppColors.surfaceHigh,
                    color: AppColors.primary,
                    minHeight: context.adaptiveSpacing(8),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: context.adaptiveSpacing(16)),
          Text(
            '${(_completeness * 100).toInt()}%', 
            style: TextStyle(
              fontSize: context.adaptiveTextSize(20), 
              fontWeight: FontWeight.bold, 
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title, 
          style: GoogleFonts.outfit(
            fontSize: context.adaptiveTextSize(18),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: context.adaptiveSpacing(16)),
        GlassContainer(
          padding: EdgeInsets.all(context.adaptiveSpacing(16)),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildAiAutofillCard() {
    return GlassContainer(
      padding: EdgeInsets.all(context.adaptiveSpacing(16)),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(context.adaptiveSpacing(8)),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome, color: AppColors.primary, size: context.adaptiveIconSize(24)),
              ),
              SizedBox(width: context.adaptiveSpacing(16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Magic AI Autofill', 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: context.adaptiveTextSize(16)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Upload your resume and let AI fill the form for you.', 
                      style: TextStyle(
                        fontSize: context.adaptiveTextSize(12), 
                        color: AppColors.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.adaptiveSpacing(16)),
          NeonButton(
            text: 'Upload Resume & Autofill',
            isLoading: _isAiParsing,
            onPressed: _pickAndParseResume,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: TextStyle(fontSize: context.adaptiveTextSize(14))),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white70, fontSize: context.adaptiveTextSize(12))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.outline.withValues(alpha: 0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: Colors.white),
              items: items.map((String item) {
                return DropdownMenuItem<String>(value: item, child: Text(item));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
