import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/colors.dart';
import '../core/theme.dart';
import '../services/offline_cache_service.dart';
import 'log_bolus_screen.dart';
import 'log_basal_screen.dart';
import 'log_hypo_screen.dart';
import 'wellness_screen.dart';

class LogHubScreen extends StatefulWidget {
  const LogHubScreen({super.key});
  @override
  State<LogHubScreen> createState() => _LogHubScreenState();
}

class _LogHubScreenState extends State<LogHubScreen> {
  final _cache = OfflineCacheService();
  double _totalBolus = 0;
  double _totalBasal = 0;
  int _pendingCount = 0;
  List<Map<String, dynamic>> _boluses = [];
  List<Map<String, dynamic>> _basals = [];

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  void _loadSummary() {
    setState(() {
      _boluses = _cache.getTodayBoluses();
      _basals = _cache.getTodayBasals();
      _totalBolus = _cache.getTodayTotalBolus();
      _totalBasal = _cache.getTodayTotalBasal();
      _pendingCount = _cache.getPendingCount();
    });
  }

  Future<void> _navigate(Widget screen) async {
    final result = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => screen));
    if (result == true && mounted) _loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Log Entry',
                  style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('What would you like to log?',
                  style: GoogleFonts.outfit(
                      fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              // Log action buttons
              Row(children: [
                Expanded(
                    child: _LogCard(
                  icon: Icons.vaccines_outlined,
                  iconColor: AppColors.accentCoral,
                  iconBg: AppColors.accentCoralLight,
                  title: 'Bolus',
                  subtitle: 'Log a bolus insulin dose',
                  badge: _totalBolus > 0
                      ? '${_totalBolus.toStringAsFixed(1)}u today'
                      : null,
                  onTap: () => _navigate(const LogBolusScreen()),
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _LogCard(
                  icon: Icons.medication_outlined,
                  iconColor: const Color(0xFF7B68EE),
                  iconBg: const Color(0xFFEEEBFF),
                  title: 'Basal',
                  subtitle: 'Log a basal insulin dose',
                  badge: _totalBasal > 0
                      ? '${_totalBasal.toStringAsFixed(0)}u today'
                      : null,
                  onTap: () => _navigate(const LogBasalScreen()),
                )),
              ]),
              const SizedBox(height: 12),
              _HypoCard(onTap: () => _navigate(const LogHypoScreen())),
              const SizedBox(height: 12),
              _WellnessCard(onTap: () => _navigate(const WellnessScreen())),
              if (_pendingCount > 0) ...[
                const SizedBox(height: 16),
                _buildPendingBanner(),
              ],
              // ── Today's full log ──────────────────────────────────────────
              const SizedBox(height: 28),
              _buildTodayLog(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayLog() {
    // Merge boluses + basals into a unified timeline sorted newest first
    final entries = <_LogEntry>[];

    for (final b in _boluses) {
      final t = DateTime.tryParse(b['time'] as String? ?? '') ?? DateTime.now();
      entries.add(_LogEntry(
        time: t,
        label: '${(b['units'] as num).toStringAsFixed(1)}u bolus',
        sub: (b['type'] ?? '').toString(),
        color: AppColors.accentCoral,
        icon: Icons.vaccines_outlined,
        pending: b['pending'] == true,
      ));
    }
    for (final b in _basals) {
      final t = DateTime.tryParse(b['time'] as String? ?? '') ?? DateTime.now();
      entries.add(_LogEntry(
        time: t,
        label: '${(b['units'] as num).toStringAsFixed(0)}u basal',
        sub: (b['insulin'] ?? '').toString(),
        color: const Color(0xFF7B68EE),
        icon: Icons.medication_outlined,
        pending: b['pending'] == true,
      ));
    }
    entries.sort((a, b) => b.time.compareTo(a.time));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Today's log",
                style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            Text(DateFormat('MMM d').format(DateTime.now()),
                style: GoogleFonts.outfit(
                    fontSize: 13, color: AppColors.textTertiary)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: AppTheme.cardDecoration,
          child: entries.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.edit_note_rounded,
                            size: 32, color: AppColors.textDisabled),
                        const SizedBox(height: 8),
                        Text('No entries logged today',
                            style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: AppColors.textTertiary)),
                        const SizedBox(height: 4),
                        Text('Use the buttons above to log insulin',
                            style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: AppColors.textDisabled)),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: entries.asMap().entries.map((e) {
                    final isLast = e.key == entries.length - 1;
                    return _buildLogRow(e.value, isLast: isLast);
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildLogRow(_LogEntry entry, {required bool isLast}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom:
                    BorderSide(color: AppColors.borderSubtle, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: entry.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(entry.icon, color: entry.color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.label,
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                if (entry.sub.isNotEmpty)
                  Text(entry.sub,
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: AppColors.textTertiary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(DateFormat('HH:mm').format(entry.time),
                  style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary)),
              if (entry.pending)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.accentWarning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('pending sync',
                      style: GoogleFonts.outfit(
                          fontSize: 9, color: AppColors.accentWarning)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accentWarning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.accentWarning.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.cloud_off_rounded,
            size: 16, color: AppColors.accentWarning),
        const SizedBox(width: 8),
        Expanded(
            child: Text(
                '$_pendingCount log${_pendingCount > 1 ? "s" : ""} saved locally — will sync when online',
                style: GoogleFonts.outfit(
                    fontSize: 12, color: AppColors.accentWarning))),
      ]),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _LogEntry {
  final DateTime time;
  final String label;
  final String sub;
  final Color color;
  final IconData icon;
  final bool pending;
  _LogEntry({
    required this.time,
    required this.label,
    required this.sub,
    required this.color,
    required this.icon,
    required this.pending,
  });
}

// ── Reusable card widgets ─────────────────────────────────────────────────────

class _LogCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconBg;
  final String title, subtitle;
  final String? badge;
  final VoidCallback onTap;
  const _LogCard(
      {required this.icon,
      required this.iconColor,
      required this.iconBg,
      required this.title,
      required this.subtitle,
      this.badge,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration
            .copyWith(borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 24)),
          const SizedBox(height: 16),
          Text(title,
              style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.3)),
          if (badge != null) ...[
            const SizedBox(height: 8),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(badge!,
                    style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: iconColor))),
          ],
        ]),
      ),
    );
  }
}

class _HypoCard extends StatelessWidget {
  final VoidCallback onTap;
  const _HypoCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration
            .copyWith(borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: AppColors.lowHypoBg,
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.warning_amber_rounded,
                  color: AppColors.accentRed, size: 24)),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Hypo Event',
                    style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text('Log a hypoglycaemia event',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppColors.textSecondary)),
              ])),
          const Icon(Icons.chevron_right,
              color: AppColors.textTertiary, size: 20),
        ]),
      ),
    );
  }
}

class _WellnessCard extends StatelessWidget {
  final VoidCallback onTap;
  const _WellnessCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration
            .copyWith(borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: AppColors.accentGreenLight,
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.spa_outlined,
                  color: AppColors.accentGreen, size: 24)),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Wellness',
                    style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text('Water & vitamins tracker',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppColors.textSecondary)),
              ])),
          const Icon(Icons.chevron_right,
              color: AppColors.textTertiary, size: 20),
        ]),
      ),
    );
  }
}
