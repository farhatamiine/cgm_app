import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../services/juggluco_service.dart';
import '../services/user_profile_service.dart';

class AlertThresholdsScreen extends StatefulWidget {
  const AlertThresholdsScreen({super.key});

  @override
  State<AlertThresholdsScreen> createState() => _AlertThresholdsScreenState();
}

class _AlertThresholdsScreenState extends State<AlertThresholdsScreen> {
  final _profileService = UserProfileService();

  final _hypoController = TextEditingController(text: '70');
  final _highController = TextEditingController(text: '250');
  final _hypoCheckController = TextEditingController(text: '15');
  final _highCheckController = TextEditingController(text: '30');

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _profileService.init();
    setState(() {
      if (_profileService.hypoThreshold > 0) {
        _hypoController.text = _profileService.hypoThreshold.toString();
      }
      if (_profileService.highThreshold > 0) {
        _highController.text = _profileService.highThreshold.toString();
      }
      if (_profileService.hypoCheckMinutes > 0) {
        _hypoCheckController.text =
            _profileService.hypoCheckMinutes.toString();
      }
      if (_profileService.highCheckMinutes > 0) {
        _highCheckController.text =
            _profileService.highCheckMinutes.toString();
      }
    });
  }

  @override
  void dispose() {
    _hypoController.dispose();
    _highController.dispose();
    _hypoCheckController.dispose();
    _highCheckController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _profileService.saveAlertSettings(
        alertsEnabled: _profileService.alertsEnabled,
        hypoThreshold: int.tryParse(_hypoController.text) ?? 70,
        highThreshold: int.tryParse(_highController.text) ?? 250,
        hypoCheckMinutes: int.tryParse(_hypoCheckController.text) ?? 15,
        highCheckMinutes: int.tryParse(_highCheckController.text) ?? 30,
        hypoRemindEat: true,
        highRemindInject: true,
      );
      JugglucoService().restart();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Settings saved!', style: GoogleFonts.outfit()),
            backgroundColor: AppColors.accentGreen));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e', style: GoogleFonts.outfit()),
            backgroundColor: AppColors.accentRed));
        setState(() => _saving = false);
      }
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
        title: Text('Alert Thresholds',
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
            _sectionLabel('Glucose levels'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _field('Hypo threshold', _hypoController,
                      'mg/dL', AppColors.accentGreen)),
              const SizedBox(width: 12),
              Expanded(
                  child: _field('High threshold', _highController,
                      'mg/dL', AppColors.accentRed)),
            ]),
            const SizedBox(height: 28),

            _sectionLabel('Check intervals'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _field('After hypo', _hypoCheckController,
                      'min', AppColors.accentGreen)),
              const SizedBox(width: 12),
              Expanded(
                  child: _field('After high', _highCheckController,
                      'min', AppColors.accentRed)),
            ]),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.bgMuted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: AppColors.textTertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Check interval sets how many minutes after a glucose event you\'ll be reminded to eat (hypo) or inject (high).',
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
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
                            fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textTertiary,
          letterSpacing: 1.0),
    );
  }

  Widget _field(String label, TextEditingController controller,
      String suffix, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.outfit(
                fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style:
              GoogleFonts.outfit(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            suffixText: suffix,
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
              borderSide: BorderSide(color: accentColor, width: 1.5),
            ),
            filled: true,
            fillColor: AppColors.bgCard,
          ),
        ),
      ],
    );
  }
}
