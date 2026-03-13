import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../services/user_profile_service.dart';

class TargetRangeScreen extends StatefulWidget {
  const TargetRangeScreen({super.key});

  @override
  State<TargetRangeScreen> createState() => _TargetRangeScreenState();
}

class _TargetRangeScreenState extends State<TargetRangeScreen> {
  final _profileService = UserProfileService();

  int _low = 70;
  int _high = 180;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _profileService.init();
    setState(() {
      _low = _profileService.targetLow > 0 ? _profileService.targetLow : 70;
      _high =
          _profileService.targetHigh > 0 ? _profileService.targetHigh : 180;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _profileService.saveTargets(low: _low, high: _high);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Target range saved!', style: GoogleFonts.outfit()),
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
        title: Text('Target Range',
            style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current range display
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                      color: AppColors.shadowColor,
                      blurRadius: 8,
                      offset: Offset(0, 2))
                ],
              ),
              child: Row(
                children: [
                  _rangeChip('Low', '$_low', AppColors.accentGreen,
                      AppColors.accentGreenLight),
                  Expanded(
                    child: Center(
                      child: Text('mg/dL',
                          style: GoogleFonts.outfit(
                              fontSize: 12, color: AppColors.textTertiary)),
                    ),
                  ),
                  _rangeChip(
                      'High', '$_high', AppColors.accentRed, AppColors.lowHypoBg),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Low slider
            _sliderSection(
              title: 'Low threshold',
              subtitle: 'Alert when glucose drops below',
              value: _low.toDouble(),
              min: 54,
              max: 100,
              divisions: 46,
              color: AppColors.accentGreen,
              onChanged: (v) => setState(() => _low = v.round()),
            ),
            const SizedBox(height: 28),

            // High slider
            _sliderSection(
              title: 'High threshold',
              subtitle: 'Alert when glucose rises above',
              value: _high.toDouble(),
              min: 140,
              max: 300,
              divisions: 160,
              color: AppColors.accentRed,
              onChanged: (v) => setState(() => _high = v.round()),
            ),

            const Spacer(),

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

  Widget _rangeChip(
      String label, String value, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }

  Widget _sliderSection({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(subtitle,
            style: GoogleFonts.outfit(
                fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(min.round().toString(),
                style: GoogleFonts.outfit(
                    fontSize: 11, color: AppColors.textTertiary)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: color,
                  thumbColor: color,
                  inactiveTrackColor: AppColors.borderSubtle,
                  overlayColor: color.withValues(alpha: 0.15),
                ),
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: value.round().toString(),
                  onChanged: onChanged,
                ),
              ),
            ),
            Text(max.round().toString(),
                style: GoogleFonts.outfit(
                    fontSize: 11, color: AppColors.textTertiary)),
          ],
        ),
      ],
    );
  }
}
