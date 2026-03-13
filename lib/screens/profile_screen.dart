import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../services/juggluco_service.dart';
import '../services/user_profile_service.dart';
import '../widgets/primary_button.dart';
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

  // Alert & CGM settings
  bool _alertsEnabled = false;
  bool _jugglucoEnabled = false;
  final _hypoThresholdController = TextEditingController(text: '70');
  final _highThresholdController = TextEditingController(text: '250');
  final _hypoCheckAfterController = TextEditingController(text: '15');
  final _highCheckAfterController = TextEditingController(text: '30');
  final _jugglucoUrlController = TextEditingController(text: 'http://127.0.0.1:17580');

  @override
  void initState() {
    super.initState();
    _initProfile();
  }

  Future<void> _initProfile() async {
    await _profileService.init();
    setState(() {
      _nameController.text = _profileService.name;
      _ageController.text = _profileService.age > 0 ? _profileService.age.toString() : '';
      _weightController.text = _profileService.weight > 0 ? _profileService.weight.toString() : '';
      _heightController.text = _profileService.height > 0 ? _profileService.height.toString() : '';
      _basalUnitController.text = _profileService.basalUnit > 0 ? _profileService.basalUnit.toString() : '';
      _targetLow = _profileService.targetLow > 0 ? _profileService.targetLow : 70;
      _targetHigh = _profileService.targetHigh > 0 ? _profileService.targetHigh : 180;
      _alertsEnabled = _profileService.alertsEnabled;
      _jugglucoEnabled = _profileService.jugglucoEnabled;
      if (_profileService.hypoThreshold > 0) {
        _hypoThresholdController.text = _profileService.hypoThreshold.toString();
      }
      if (_profileService.highThreshold > 0) {
        _highThresholdController.text = _profileService.highThreshold.toString();
      }
      if (_profileService.hypoCheckMinutes > 0) {
        _hypoCheckAfterController.text = _profileService.hypoCheckMinutes.toString();
      }
      if (_profileService.highCheckMinutes > 0) {
        _highCheckAfterController.text = _profileService.highCheckMinutes.toString();
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

  Future<void> _analyseProfile() async {
    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text);
    final weight = int.tryParse(_weightController.text);
    final height = int.tryParse(_heightController.text);
    final basalUnit = int.tryParse(_basalUnitController.text);

    if (name.isEmpty || age == null || weight == null || height == null || basalUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Please fill all profile fields', style: GoogleFonts.outfit()),
            backgroundColor: AppColors.accentRed),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Profile analysed!', style: GoogleFonts.outfit()),
              backgroundColor: AppColors.accentGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e', style: GoogleFonts.outfit()),
              backgroundColor: AppColors.accentRed),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Profile saved!', style: GoogleFonts.outfit()),
              backgroundColor: AppColors.accentGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving: $e', style: GoogleFonts.outfit()),
              backgroundColor: AppColors.accentRed),
        );
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _saveAlertSettings() async {
    final hypoThreshold = int.tryParse(_hypoThresholdController.text) ?? 70;
    final highThreshold = int.tryParse(_highThresholdController.text) ?? 250;
    final hypoCheckAfter = int.tryParse(_hypoCheckAfterController.text) ?? 15;
    final highCheckAfter = int.tryParse(_highCheckAfterController.text) ?? 30;
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
      // Apply Juggluco changes immediately — restart the polling service
      JugglucoService().restart();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Alert settings saved!', style: GoogleFonts.outfit()),
              backgroundColor: AppColors.accentGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving alerts: $e', style: GoogleFonts.outfit()),
              backgroundColor: AppColors.accentRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Profile Info ──────────────────────────────────
                  _buildProfileCard(),
                  const SizedBox(height: 24),
                  _sectionLabel('Profile Info'),
                  const SizedBox(height: 10),
                  _buildProfileFields(),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'Analyse My Profile',
                    onPressed: _analyseProfile,
                    isLoading: _analysing,
                  ),
                  if (_analysisResult != null) ...[
                    const SizedBox(height: 12),
                    _buildAnalysisResult(),
                  ],
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'Save Profile',
                    onPressed: _saveProfile,
                    isLoading: _savingProfile,
                  ),

                  // ── Health ────────────────────────────────────────
                  const SizedBox(height: 28),
                  _sectionLabel('Health'),
                  const SizedBox(height: 10),
                  _buildTargetRange(),

                  // ── Alerts & CGM ──────────────────────────────────
                  const SizedBox(height: 28),
                  _sectionLabel('Alerts & CGM'),
                  const SizedBox(height: 10),
                  _buildAlertsCgmSection(),

                  // ── Reports ───────────────────────────────────────
                  const SizedBox(height: 28),
                  _sectionLabel('Reports'),
                  const SizedBox(height: 10),
                  _buildMonthlyReportCard(),

                  // ── Settings ──────────────────────────────────────
                  const SizedBox(height: 28),
                  _sectionLabel('Settings'),
                  const SizedBox(height: 10),
                  _buildMenuGroup([
                    _MenuItem(
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      trailing: 'Enabled',
                    ),
                    _MenuItem(
                      icon: Icons.bluetooth_outlined,
                      label: 'CGM Connection',
                      trailing: 'Not connected',
                    ),
                  ]),

                  // ── Account ───────────────────────────────────────
                  const SizedBox(height: 28),
                  _sectionLabel('Account'),
                  const SizedBox(height: 10),
                  _buildMenuGroup([
                    _MenuItem(
                      icon: Icons.share_outlined,
                      label: 'Share with Provider',
                    ),
                    _MenuItem(
                      icon: Icons.privacy_tip_outlined,
                      label: 'Privacy & Data',
                    ),
                    _MenuItem(
                      icon: Icons.help_outline_rounded,
                      label: 'Help & Support',
                    ),
                    _MenuItem(
                      icon: Icons.logout_rounded,
                      label: 'Sign Out',
                      isDestructive: true,
                    ),
                  ]),

                  const SizedBox(height: 20),
                  Center(
                    child: Text('GlucoTrack v1.0.0',
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: AppColors.textTertiary)),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Text('Profile',
          style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
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

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accentCoral,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Center(
              child: Text(
                _nameController.text.isNotEmpty
                    ? _nameController.text[0].toUpperCase()
                    : 'S',
                style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_nameController.text.isNotEmpty ? _nameController.text : 'Your Name',
                    style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                Text('Type 1 Diabetic',
                    style: GoogleFonts.outfit(
                        fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right,
              color: AppColors.textTertiary, size: 18),
        ],
      ),
    );
  }

  Widget _buildTargetRange() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Target Range',
              style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _editableRangeField('Low', _targetLow, (v) {
                setState(() => _targetLow = v);
              })),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('—',
                    style: GoogleFonts.outfit(
                        color: AppColors.textTertiary, fontSize: 20)),
              ),
              Expanded(child: _editableRangeField('High', _targetHigh, (v) {
                setState(() => _targetHigh = v);
              })),
              const SizedBox(width: 8),
              Text('mg/dL',
                  style: GoogleFonts.outfit(
                      fontSize: 13, color: AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Low: $_targetLow  —  High: $_targetHigh mg/dL',
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.accentGreen,
              thumbColor: AppColors.accentGreen,
              inactiveTrackColor: AppColors.borderSubtle,
              overlayColor: AppColors.accentGreen.withOpacity(0.2),
            ),
            child: Column(children: [
              Row(children: [
                Text('Low', style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textTertiary)),
                Expanded(child: Slider(
                  value: _targetLow.toDouble(),
                  min: 54,
                  max: 100,
                  divisions: 46,
                  label: '$_targetLow',
                  onChanged: (v) => setState(() => _targetLow = v.round()),
                )),
                Text('$_targetLow', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ]),
              Row(children: [
                Text('High', style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textTertiary)),
                Expanded(child: Slider(
                  value: _targetHigh.toDouble(),
                  min: 140,
                  max: 300,
                  divisions: 160,
                  label: '$_targetHigh',
                  onChanged: (v) => setState(() => _targetHigh = v.round()),
                )),
                Text('$_targetHigh', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _editableRangeField(String label, int value, ValueChanged<int> onChanged) {
    final controller = TextEditingController(text: value.toString());
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
          style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              borderSide:
                  const BorderSide(color: AppColors.accentGreen, width: 1.5),
            ),
            filled: true,
            fillColor: AppColors.bgCard,
          ),
          onChanged: (v) {
            final parsed = int.tryParse(v);
            if (parsed != null) onChanged(parsed);
          },
        ),
      ],
    );
  }

  Widget _buildAlertsCgmSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Alerts Enabled toggle
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Alerts Enabled', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
              Text('Receive hypo and high glucose alerts', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
            ])),
            Switch(
              value: _alertsEnabled,
              onChanged: (v) => setState(() => _alertsEnabled = v),
              activeColor: AppColors.accentGreen,
            ),
          ]),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 16),

          // Threshold fields
          Row(children: [
            Expanded(child: _profileField('Hypo Threshold (mg/dL)', _hypoThresholdController, TextInputType.number, '')),
            const SizedBox(width: 12),
            Expanded(child: _profileField('High Threshold (mg/dL)', _highThresholdController, TextInputType.number, '')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _profileField('Hypo Check After (min)', _hypoCheckAfterController, TextInputType.number, '')),
            const SizedBox(width: 12),
            Expanded(child: _profileField('High Check After (min)', _highCheckAfterController, TextInputType.number, '')),
          ]),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 16),

          // Juggluco URL
          _profileField('Juggluco URL', _jugglucoUrlController, TextInputType.url, ''),
          const SizedBox(height: 12),

          // Enable Juggluco toggle
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Enable Juggluco', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
              Text('Fetch readings from Juggluco app', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
            ])),
            Switch(
              value: _jugglucoEnabled,
              onChanged: (v) => setState(() => _jugglucoEnabled = v),
              activeColor: AppColors.accentGreen,
            ),
          ]),
          const SizedBox(height: 16),

          // Save Alert Settings button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveAlertSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text('Save Alert Settings', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileFields() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _profileField('Full Name', _nameController, TextInputType.name, ''),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _profileField(
                    'Age', _ageController, TextInputType.number, 'years')),
            const SizedBox(width: 12),
            Expanded(
                child: _profileField(
                    'Weight', _weightController, TextInputType.number, 'kg')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _profileField(
                    'Height', _heightController, TextInputType.number, 'cm')),
            const SizedBox(width: 12),
            Expanded(
                child: _profileField('Basal Units', _basalUnitController,
                    TextInputType.number, 'u/day')),
          ]),
        ],
      ),
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
          style:
              GoogleFonts.outfit(fontSize: 14, color: AppColors.textPrimary),
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
        borderRadius: BorderRadius.circular(16),
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
                              fontSize: 12, color: AppColors.textPrimary))),
                ]),
              )),
        ],
      ),
    );
  }

  Widget _buildMonthlyReportCard() {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const MonthlyReportScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3D8A5A), Color(0xFF4D9B6A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.insert_drive_file_outlined,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Monthly Report',
                      style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  Text('View & download full report',
                      style:
                          GoogleFonts.outfit(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
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
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(item.icon,
                        size: 20,
                        color: item.isDestructive
                            ? AppColors.accentRed
                            : AppColors.textSecondary),
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
                    if (item.trailing != null && item.trailing!.isNotEmpty)
                      Text(item.trailing!,
                          style: GoogleFonts.outfit(
                              fontSize: 13, color: AppColors.textTertiary)),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right,
                        size: 18,
                        color: item.isDestructive
                            ? AppColors.accentRed
                            : AppColors.textTertiary),
                  ],
                ),
              ),
              if (!isLast)
                const Divider(height: 1, color: AppColors.borderSubtle),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String? trailing;
  final bool isDestructive;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.trailing,
    this.isDestructive = false,
  });
}
