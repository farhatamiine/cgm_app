import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../services/api_service.dart';
import '../services/user_profile_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _api = ApiService();
  final _profileService = UserProfileService();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _basalUnitController = TextEditingController();

  bool _analysing = false;
  bool _saving = false;
  Map<String, dynamic>? _analysisResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _profileService.init();
    setState(() {
      _nameController.text = _profileService.name;
      _ageController.text =
          _profileService.age > 0 ? _profileService.age.toString() : '';
      _weightController.text =
          _profileService.weight > 0 ? _profileService.weight.toString() : '';
      _heightController.text =
          _profileService.height > 0 ? _profileService.height.toString() : '';
      _basalUnitController.text = _profileService.basalUnit > 0
          ? _profileService.basalUnit.toString()
          : '';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _basalUnitController.dispose();
    super.dispose();
  }

  Future<void> _analyse() async {
    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text);
    final weight = int.tryParse(_weightController.text);
    final height = int.tryParse(_heightController.text);
    final basalUnit = int.tryParse(_basalUnitController.text);

    if (name.isEmpty ||
        age == null ||
        weight == null ||
        height == null ||
        basalUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Please fill all fields', style: GoogleFonts.outfit()),
          backgroundColor: AppColors.accentRed));
      return;
    }

    setState(() => _analysing = true);
    try {
      final result = await _api.analyseUser(
        fullName: name,
        age: age,
        weight: weight,
        basalUnit: basalUnit,
        height: height,
      );
      setState(() {
        _analysisResult = result;
        _analysing = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e', style: GoogleFonts.outfit()),
            backgroundColor: AppColors.accentRed));
      }
      setState(() => _analysing = false);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text) ?? 0;
    final weight = int.tryParse(_weightController.text) ?? 0;
    final height = int.tryParse(_heightController.text) ?? 0;
    final basalUnit = int.tryParse(_basalUnitController.text) ?? 0;

    setState(() => _saving = true);
    try {
      await _profileService.saveProfile(
        name: name,
        age: age,
        weight: weight,
        height: height,
        basalUnit: basalUnit,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Profile saved!', style: GoogleFonts.outfit()),
            backgroundColor: AppColors.accentGreen));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e', style: GoogleFonts.outfit()),
            backgroundColor: AppColors.accentRed));
      }
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Edit Profile',
            style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field('Full Name', _nameController, TextInputType.name, ''),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child:
                      _field('Age', _ageController, TextInputType.number, 'yrs')),
              const SizedBox(width: 12),
              Expanded(
                  child: _field(
                      'Weight', _weightController, TextInputType.number, 'kg')),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: _field(
                      'Height', _heightController, TextInputType.number, 'cm')),
              const SizedBox(width: 12),
              Expanded(
                  child: _field('Basal Units', _basalUnitController,
                      TextInputType.number, 'u/day')),
            ]),
            if (_analysisResult != null) ...[
              const SizedBox(height: 20),
              _buildAnalysisResult(),
            ],
            const SizedBox(height: 32),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _analysing ? null : _analyse,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: const BorderSide(color: AppColors.accentGreen),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _analysing
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accentGreen))
                      : Text('Analyse',
                          style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentGreen)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentGreen,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('Save',
                          style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller,
      TextInputType type, String suffix) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.outfit(
                fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: type,
          style:
              GoogleFonts.outfit(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            suffixText: suffix.isNotEmpty ? suffix : null,
            suffixStyle: GoogleFonts.outfit(
                fontSize: 12, color: AppColors.textTertiary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.accentCoral, width: 1.5),
            ),
            filled: true,
            fillColor: AppColors.bgCard,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisResult() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentGreenLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.check_circle_outline,
                color: AppColors.accentGreen, size: 16),
            const SizedBox(width: 8),
            Text('Analysis Result',
                style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentGreen)),
          ]),
          const SizedBox(height: 8),
          ..._analysisResult!.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Text('${e.key}: ',
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  Expanded(
                      child: Text('${e.value}',
                          style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppColors.textPrimary))),
                ]),
              )),
        ],
      ),
    );
  }
}
