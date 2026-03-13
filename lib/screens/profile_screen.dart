import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../core/theme.dart';
import '../services/juggluco_service.dart';
import '../services/user_profile_service.dart';
import 'alert_thresholds_screen.dart';
import 'edit_profile_screen.dart';
import 'juggluco_url_screen.dart';
import 'monthly_report_screen.dart';
import 'target_range_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileService = UserProfileService();

  String _name = '';
  int _targetLow = 70;
  int _targetHigh = 180;
  bool _alertsEnabled = false;
  bool _jugglucoEnabled = false;
  int _hypoThreshold = 70;
  int _highThreshold = 250;
  String _jugglucoUrl = 'http://127.0.0.1:17580';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _profileService.init();
    setState(() {
      _name = _profileService.name;
      _targetLow =
          _profileService.targetLow > 0 ? _profileService.targetLow : 70;
      _targetHigh =
          _profileService.targetHigh > 0 ? _profileService.targetHigh : 180;
      _alertsEnabled = _profileService.alertsEnabled;
      _jugglucoEnabled = _profileService.jugglucoEnabled;
      _hypoThreshold =
          _profileService.hypoThreshold > 0 ? _profileService.hypoThreshold : 70;
      _highThreshold = _profileService.highThreshold > 0
          ? _profileService.highThreshold
          : 250;
      if (_profileService.jugglucoUrl.isNotEmpty) {
        _jugglucoUrl = _profileService.jugglucoUrl;
      }
    });
  }

  Future<void> _pushAndReload(Widget screen) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  Future<void> _saveToggle() async {
    try {
      await _profileService.saveAlertSettings(
        alertsEnabled: _alertsEnabled,
        hypoThreshold: _hypoThreshold,
        highThreshold: _highThreshold,
        hypoCheckMinutes: _profileService.hypoCheckMinutes,
        highCheckMinutes: _profileService.highCheckMinutes,
        hypoRemindEat: true,
        highRemindInject: true,
      );
      await _profileService.saveJugglucoSettings(
        url: _jugglucoUrl,
        enabled: _jugglucoEnabled,
        pollSeconds: 120,
      );
      JugglucoService().restart();
    } catch (_) {}
  }

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

              _buildProfileHeader(),
              const SizedBox(height: 28),

              _sectionLabel('Health'),
              const SizedBox(height: 10),
              _buildMenuGroup([
                _MenuItem(
                  icon: Icons.tune_rounded,
                  label: 'Target Range',
                  trailing: '$_targetLow – $_targetHigh mg/dL',
                  onTap: () =>
                      _pushAndReload(const TargetRangeScreen()),
                ),
                _MenuItem(
                  icon: Icons.insert_drive_file_outlined,
                  label: 'Monthly Report',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MonthlyReportScreen())),
                ),
              ]),
              const SizedBox(height: 28),

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
                      _saveToggle();
                    },
                    activeThumbColor: AppColors.accentGreen,
                  ),
                ),
                _MenuItem(
                  icon: Icons.speed_outlined,
                  label: 'Alert Thresholds',
                  trailing: '$_hypoThreshold / $_highThreshold',
                  onTap: () =>
                      _pushAndReload(const AlertThresholdsScreen()),
                ),
                _MenuItem(
                  icon: Icons.bluetooth_outlined,
                  label: 'Juggluco CGM',
                  trailingWidget: Switch(
                    value: _jugglucoEnabled,
                    onChanged: (v) {
                      setState(() => _jugglucoEnabled = v);
                      _saveToggle();
                    },
                    activeThumbColor: AppColors.accentGreen,
                  ),
                ),
                _MenuItem(
                  icon: Icons.link_rounded,
                  label: 'Juggluco URL',
                  trailing: _jugglucoUrl
                      .replaceFirst('http://', '')
                      .replaceFirst('https://', ''),
                  onTap: () =>
                      _pushAndReload(const JugglucoUrlScreen()),
                ),
              ]),
              const SizedBox(height: 28),

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

  Widget _buildProfileHeader() {
    final initial =
        _name.isNotEmpty ? _name[0].toUpperCase() : '?';
    final displayName = _name.isNotEmpty ? _name : 'Your Name';

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
          Text(displayName,
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
              onPressed: () =>
                  _pushAndReload(const EditProfileScreen()),
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
