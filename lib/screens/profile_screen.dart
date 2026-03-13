import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../services/juggluco_service.dart';
import '../services/user_profile_service.dart';
import 'monthly_report_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiService();
  final _profileService = UserProfileService();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _basalUnitController = TextEditingController();

  int _targetLow = 70;
  int _targetHigh = 180;
  bool _analysing = false;
  bool _savingProfile = false;
  Map<String, dynamic>? _analysisResult;

  bool _alertsEnabled = false;
  bool _jugglucoEnabled = false;
  final _hypoThresholdController = TextEditingController(text: '70');
  final _highThresholdController = TextEditingController(text: '250');
  final _hypoCheckAfterController = TextEditingController(text: '15');
  final _highCheckAfterController = TextEditingController(text: '30');
  final _jugglucoUrlController =
      TextEditingController(text: 'http://127.0.0.1:17580');

  @override
  void initState() {
    super.initState();
    _initProfile();
  }

  Future<void> _initProfile() async {
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
      _targetLow =
          _profileService.targetLow > 0 ? _profileService.targetLow : 70;
      _targetHigh =
          _profileService.targetHigh > 0 ? _profileService.targetHigh : 180;
      _alertsEnabled = _profileService.alertsEnabled;
      _jugglucoEnabled = _profileService.jugglucoEnabled;
      if (_profileService.hypoThreshold > 0) {
        _hypoThresholdController.text =
            _profileService.hypoThreshold.toString();
      }
      if (_profileService.highThreshold > 0) {
        _highThresholdController.text =
            _profileService.highThreshold.toString();
      }
      if (_profileService.hypoCheckMinutes > 0) {
        _hypoCheckAfterController.text =
            _profileService.hypoCheckMinutes.toString();
      }
      if (_profileService.highCheckMinutes > 0) {
        _highCheckAfterController.text =
            _profileService.highCheckMinutes.toString();
      }
      if (_profileService.jugglucoUrl.isNotEmpty) {
        _jugglucoUrlController.text = _profileService.jugglucoUrl;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _basalUnitController.dispose();
    _hypoThresholdController.dispose();
    _highThresholdController.dispose();
    _hypoCheckAfterController.dispose();
    _highCheckAfterController.dispose();
    _jugglucoUrlController.dispose();
    super.dispose();
  }

  // ── Business logic ─────────────────────────────────────────────────────────

  Future<void> _analyseProfile() async {
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
          content:
              Text('Please fill all profile fields', style: GoogleFonts.outfit()),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Profile analysed!', style: GoogleFonts.outfit()),
            backgroundColor: AppColors.accentGreen));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e', style: GoogleFonts.outfit()),
            backgroundColor: AppColors.accentRed));
      }
      setState(() => _analysing = false);
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text) ?? 0;
    final weight = int.tryParse(_weightController.text) ?? 0;
    final height = int.tryParse(_heightController.text) ?? 0;
    final basalUnit = int.tryParse(_basalUnitController.text) ?? 0;

    setState(() => _savingProfile = true);
    try {
      await _profileService.saveProfile(
        name: name,
        age: age,
        weight: weight,
        height: height,
        basalUnit: basalUnit,
      );
      await _profileService.saveTargets(low: _targetLow, high: _targetHigh);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Profile saved!', style: GoogleFonts.outfit()),
            backgroundColor: AppColors.accentGreen));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error saving: $e', style: GoogleFonts.outfit()),
            backgroundColor: AppColors.accentRed));
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _saveAlertSettings() async {
    final hypoThreshold =
        int.tryParse(_hypoThresholdController.text) ?? 70;
    final highThreshold =
        int.tryParse(_highThresholdController.text) ?? 250;
    final hypoCheckAfter =
        int.tryParse(_hypoCheckAfterController.text) ?? 15;
    final highCheckAfter =
        int.tryParse(_highCheckAfterController.text) ?? 30;
    final jugglucoUrl = _jugglucoUrlController.text.trim();

    try {
      await _profileService.saveAlertSettings(
        alertsEnabled: _alertsEnabled,
        hypoThreshold: hypoThreshold,
        highThreshold: highThreshold,
        hypoCheckMinutes: hypoCheckAfter,
        highCheckMinutes: highCheckAfter,
        hypoRemindEat: true,
        highRemindInject: true,
      );
      await _profileService.saveJugglucoSettings(
        url: jugglucoUrl,
        enabled: _jugglucoEnabled,
        pollSeconds: 120,
      );
      JugglucoService().restart();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Settings saved!', style: GoogleFonts.outfit()),
            backgroundColor: AppColors.accentGreen));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e', style: GoogleFonts.outfit()),
            backgroundColor: AppColors.accentRed));
      }
    }
  }

  // ── Sheets ─────────────────────────────────────────────────────────────────

  void _showEditProfileSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Edit Profile',
                  style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 20),
              _profileField(
                  'Full Name', _nameController, TextInputType.name, ''),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _profileField(
                        'Age', _ageController, TextInputType.number, 'yrs')),
                const SizedBox(width: 12),
                Expanded(
                    child: _profileField('Weight', _weightController,
                        TextInputType.number, 'kg')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _profileField('Height', _heightController,
                        TextInputType.number, 'cm')),
                const SizedBox(width: 12),
                Expanded(
                    child: _profileField('Basal Units', _basalUnitController,
                        TextInputType.number, 'u/day')),
              ]),
              if (_analysisResult != null) ...[
                const SizedBox(height: 16),
                _buildAnalysisResult(),
              ],
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _analysing ? null : _analyseProfile,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.accentGreen),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _analysing
                        ? const SizedBox(
                            height: 16,
                            width: 16,
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
                    onPressed: _savingProfile
                        ? null
                        : () async {
                            await _saveProfile();
                            if (mounted) {
                              setState(() {});
                              Navigator.pop(ctx);
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _savingProfile
                        ? const SizedBox(
                            height: 16,
                            width: 16,
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
      ),
    );
  }

  void _showTargetRangeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Target Range',
                  style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('$_targetLow – $_targetHigh mg/dL',
                  style: GoogleFonts.outfit(
                      fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              _rangeSliderRow(
                label: 'Low',
                value: _targetLow.toDouble(),
                min: 54, max: 100, divisions: 46,
                color: AppColors.accentGreen,
                onChanged: (v) {
                  setSheet(() => _targetLow = v.round());
                  setState(() {});
                },
              ),
              _rangeSliderRow(
                label: 'High',
                value: _targetHigh.toDouble(),
                min: 140, max: 300, divisions: 160,
                color: AppColors.accentRed,
                onChanged: (v) {
                  setSheet(() => _targetHigh = v.round());
                  setState(() {});
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await _profileService.saveTargets(
                        low: _targetLow, high: _targetHigh);
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              Text('Saved!', style: GoogleFonts.outfit()),
                          backgroundColor: AppColors.accentGreen));
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Save',
                      style: GoogleFonts.outfit(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAlertThresholdsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Alert Thresholds',
                  style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                    child: _profileField('Hypo (mg/dL)',
                        _hypoThresholdController, TextInputType.number, '')),
                const SizedBox(width: 12),
                Expanded(
                    child: _profileField('High (mg/dL)',
                        _highThresholdController, TextInputType.number, '')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _profileField('Hypo check (min)',
                        _hypoCheckAfterController, TextInputType.number, '')),
                const SizedBox(width: 12),
                Expanded(
                    child: _profileField('High check (min)',
                        _highCheckAfterController, TextInputType.number, '')),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await _saveAlertSettings();
                    if (mounted) {
                      setState(() {});
                      Navigator.pop(ctx);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Save',
                      style: GoogleFonts.outfit(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJugglucoUrlSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Juggluco URL',
                style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text('Local URL for Juggluco web API.',
                style: GoogleFonts.outfit(
                    fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            _profileField(
                'URL', _jugglucoUrlController, TextInputType.url, ''),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  await _saveAlertSettings();
                  if (mounted) {
                    setState(() {});
                    Navigator.pop(ctx);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Save',
                    style: GoogleFonts.outfit(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profile',
                  style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 20),

              // ── Centered profile header ────────────────────────────
              _buildProfileHeader(),
              const SizedBox(height: 28),

              // ── Health ────────────────────────────────────────────
              _sectionLabel('Health'),
              const SizedBox(height: 10),
              _buildMenuGroup([
                _MenuItem(
                  icon: Icons.tune_rounded,
                  label: 'Target Range',
                  trailing: '$_targetLow – $_targetHigh mg/dL',
                  onTap: _showTargetRangeSheet,
                ),
                _MenuItem(
                  icon: Icons.insert_drive_file_outlined,
                  label: 'Monthly Report',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const MonthlyReportScreen())),
                ),
              ]),
              const SizedBox(height: 28),

              // ── Alerts & CGM ──────────────────────────────────────
              _sectionLabel('Alerts & CGM'),
              const SizedBox(height: 10),
              _buildMenuGroup([
                _MenuItem(
                  icon: Icons.notifications_outlined,
                  label: 'Glucose Alerts',
                  trailingWidget: Switch(
                    value: _alertsEnabled,
                    onChanged: (v) {
                      setState(() => _alertsEnabled = v);
                      _saveAlertSettings();
                    },
                    activeThumbColor: AppColors.accentGreen,
                  ),
                ),
                _MenuItem(
                  icon: Icons.speed_outlined,
                  label: 'Alert Thresholds',
                  trailing:
                      '${_hypoThresholdController.text} / ${_highThresholdController.text}',
                  onTap: _showAlertThresholdsSheet,
                ),
                _MenuItem(
                  icon: Icons.bluetooth_outlined,
                  label: 'Juggluco CGM',
                  trailingWidget: Switch(
                    value: _jugglucoEnabled,
                    onChanged: (v) {
                      setState(() => _jugglucoEnabled = v);
                      _saveAlertSettings();
                    },
                    activeThumbColor: AppColors.accentGreen,
                  ),
                ),
                _MenuItem(
                  icon: Icons.link_rounded,
                  label: 'Juggluco URL',
                  trailing: _jugglucoUrlController.text
                      .replaceFirst('http://', '')
                      .replaceFirst('https://', ''),
                  onTap: _showJugglucoUrlSheet,
                ),
              ]),
              const SizedBox(height: 28),

              // ── Account ───────────────────────────────────────────
              _sectionLabel('Account'),
              const SizedBox(height: 10),
              _buildMenuGroup([
                _MenuItem(
                    icon: Icons.share_outlined,
                    label: 'Share with Provider'),
                _MenuItem(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy & Data'),
                _MenuItem(
                    icon: Icons.help_outline_rounded,
                    label: 'Help & Support'),
                _MenuItem(
                    icon: Icons.logout_rounded,
                    label: 'Sign Out',
                    isDestructive: true),
              ]),

              const SizedBox(height: 28),
              Center(
                child: Text('GlucoTrack v1.0.0',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppColors.textTertiary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _buildProfileHeader() {
    final initial = _nameController.text.isNotEmpty
        ? _nameController.text[0].toUpperCase()
        : '?';
    final name = _nameController.text.isNotEmpty
        ? _nameController.text
        : 'Your Name';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.accentCoral,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(initial,
                  style: GoogleFonts.outfit(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(height: 12),
          Text(name,
              style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Type 1 Diabetic',
              style: GoogleFonts.outfit(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _showEditProfileSheet,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text('Edit Profile',
                  style: GoogleFonts.outfit(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentGreen,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
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
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildMenuGroup(List<_MenuItem> items) {
    return Container(
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final isLast = i == items.length - 1;

          return Column(
            children: [
              InkWell(
                onTap: item.trailingWidget != null ? null : item.onTap,
                borderRadius: BorderRadius.vertical(
                  top: i == 0
                      ? const Radius.circular(16)
                      : Radius.zero,
                  bottom: isLast
                      ? const Radius.circular(16)
                      : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: item.isDestructive
                              ? AppColors.accentRed.withValues(alpha: 0.1)
                              : AppColors.bgPrimary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.icon,
                            size: 18,
                            color: item.isDestructive
                                ? AppColors.accentRed
                                : AppColors.textSecondary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(item.label,
                            style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: item.isDestructive
                                    ? AppColors.accentRed
                                    : AppColors.textPrimary)),
                      ),
                      if (item.trailingWidget != null)
                        item.trailingWidget!
                      else ...[
                        if (item.trailing != null &&
                            item.trailing!.isNotEmpty)
                          Text(item.trailing!,
                              style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: AppColors.textTertiary)),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right,
                            size: 18,
                            color: item.isDestructive
                                ? AppColors.accentRed
                                : AppColors.textTertiary),
                      ],
                    ],
                  ),
                ),
              ),
              if (!isLast)
                const Divider(
                    height: 1,
                    indent: 66,
                    color: AppColors.borderSubtle),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _rangeSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
            width: 36,
            child: Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 12, color: AppColors.textTertiary))),
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
        SizedBox(
          width: 36,
          child: Text(value.round().toString(),
              style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
              textAlign: TextAlign.end),
        ),
      ],
    );
  }

  Widget _profileField(String label, TextEditingController controller,
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
          style: GoogleFonts.outfit(
              fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            suffixText: suffix.isNotEmpty ? suffix : null,
            suffixStyle: GoogleFonts.outfit(
                fontSize: 12, color: AppColors.textTertiary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: AppColors.accentCoral, width: 1.5),
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

// ── Data class ────────────────────────────────────────────────────────────────

class _MenuItem {
  final IconData icon;
  final String label;
  final String? trailing;
  final Widget? trailingWidget;
  final bool isDestructive;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.trailing,
    this.trailingWidget,
    this.isDestructive = false,
    this.onTap,
  });
}
