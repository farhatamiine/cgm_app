import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../core/theme.dart';
import '../services/health_service.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _healthService = HealthService();

  bool _connected = false;
  bool _loading = false;
  HcAvailability _hcAvailability = HcAvailability.available;
  HealthSummary _summary = HealthSummary.empty;

  // Manual water intake (ml) — not in Health Connect, tracked locally
  int _waterMl = 0;
  final int _waterGoalMl = 2000;

  // Manual sleep log (overrides Health Connect if user logs manually)
  double? _manualSleepHours;
  String _sleepQuality = 'Good';

  // Manually logged activities (merged with Health Connect)
  final List<_ManualActivity> _manualActivities = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // First check if Health Connect is present on the device
    final avail = await _healthService.checkAvailability();
    setState(() => _hcAvailability = avail);

    if (avail != HcAvailability.available) return;

    // HC is installed — check if we already have permission
    final already = await _healthService.checkPermissions();
    if (already) {
      setState(() => _connected = true);
      _loadHealthData();
    }
  }

  Future<void> _connectHealthConnect() async {
    // If HC is not installed / needs update, open Play Store
    if (_hcAvailability != HcAvailability.available) {
      await _healthService.openInstallPage();
      // Re-check after user returns from Play Store
      final avail = await _healthService.checkAvailability();
      setState(() => _hcAvailability = avail);
      return;
    }

    setState(() => _loading = true);
    final granted = await _healthService.requestPermissions();
    if (granted) {
      setState(() => _connected = true);
      await _loadHealthData();
    } else {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Permission denied. Please allow access in Health Connect settings.',
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: AppColors.accentRed,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () => _healthService.openInstallPage(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadHealthData() async {
    setState(() => _loading = true);
    final summary = await _healthService.getTodaySummary();
    setState(() {
      _summary = summary;
      _loading = false;
    });
  }

  double get _displaySleepHours =>
      _manualSleepHours ?? _summary.sleepHours;

  void _addWater(int ml) {
    setState(() => _waterMl = (_waterMl + ml).clamp(0, _waterGoalMl * 2));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _connected ? _loadHealthData : () async {},
          color: AppColors.accentGreen,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildHealthConnectCard(),
                    const SizedBox(height: 20),
                    _buildWaterCard(),
                    const SizedBox(height: 20),
                    _buildSleepCard(),
                    const SizedBox(height: 20),
                    _buildActivitiesSection(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final weekday =
        ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][now.weekday - 1];
    final month = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ][now.month - 1];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Activity',
                  style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              Text('$weekday, ${now.day} $month',
                  style: GoogleFonts.outfit(
                      fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          if (_connected)
            GestureDetector(
              onTap: _loadHealthData,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accentGreenLight,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                        color: AppColors.shadowColorDark,
                        blurRadius: 8,
                        offset: Offset(0, 2))
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _loading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accentGreen))
                        : const Icon(Icons.sync_rounded,
                            size: 14, color: AppColors.accentGreen),
                    const SizedBox(width: 6),
                    Text('Synced',
                        style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentGreen)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Health Connect card ──────────────────────────────────────────────────

  Widget _buildHealthConnectCard() {
    if (!_connected) {
      final notInstalled = _hcAvailability == HcAvailability.notInstalled;
      final needsUpdate = _hcAvailability == HcAvailability.needsUpdate;

      String title;
      String subtitle;
      if (notInstalled) {
        title = 'Install Health Connect';
        subtitle = 'Required to sync steps, sleep & workouts';
      } else if (needsUpdate) {
        title = 'Update Health Connect';
        subtitle = 'An update is required to continue';
      } else {
        title = 'Connect Health Connect';
        subtitle = 'Sync steps, calories, sleep & workouts';
      }

      return GestureDetector(
        onTap: _connectHealthConnect,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: notInstalled || needsUpdate
                  ? [const Color(0xFF5C6BC0), const Color(0xFF7986CB)]
                  : [const Color(0xFF1A73E8), const Color(0xFF4285F4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Icon(
                        notInstalled
                            ? Icons.download_outlined
                            : needsUpdate
                                ? Icons.system_update_outlined
                                : Icons.health_and_safety_outlined,
                        color: Colors.white,
                        size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                    Text(subtitle,
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      );
    }

    // Connected — show today's stats
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.health_and_safety_outlined,
                    size: 16, color: Color(0xFF1A73E8)),
              ),
              const SizedBox(width: 10),
              Text('Health Connect · Today',
                  style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          _loading
              ? const Center(
                  child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(
                      color: AppColors.accentGreen, strokeWidth: 2),
                ))
              : Row(
                  children: [
                    Expanded(
                        child: _fitStat(
                            Icons.directions_walk_rounded,
                            _formatNumber(_summary.steps),
                            'Steps',
                            AppColors.accentGreen)),
                    Expanded(
                        child: _fitStat(
                            Icons.local_fire_department_outlined,
                            '${_summary.caloriesKcal}',
                            'Kcal',
                            AppColors.accentCoral)),
                    Expanded(
                        child: _fitStat(
                            Icons.timer_outlined,
                            '${_summary.activeMinutes}',
                            'Active min',
                            const Color(0xFF7B68EE))),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _fitStat(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 6),
        Text(value,
            style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        Text(label,
            style: GoogleFonts.outfit(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  // ── Water intake ─────────────────────────────────────────────────────────

  Widget _buildWaterCard() {
    final pct = (_waterMl / _waterGoalMl).clamp(0.0, 1.0);
    final liters = _waterMl / 1000;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.water_drop_outlined,
                      size: 16, color: Color(0xFF2196F3)),
                ),
                const SizedBox(width: 10),
                Text('Water Intake',
                    style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ]),
              Text('${liters.toStringAsFixed(1)} / ${_waterGoalMl / 1000}L',
                  style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2196F3))),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: const Color(0xFFE3F2FD),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _waterBtn('+250 ml', 250),
              const SizedBox(width: 8),
              _waterBtn('+500 ml', 500),
              const SizedBox(width: 8),
              _waterBtn('+1 L', 1000),
              const Spacer(),
              GestureDetector(
                onTap: _showCustomWaterSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.bgMuted,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Custom',
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _waterBtn(String label, int ml) {
    return GestureDetector(
      onTap: () => _addWater(ml),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2196F3))),
      ),
    );
  }

  void _showCustomWaterSheet() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Water',
                  style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: GoogleFonts.outfit(
                    fontSize: 16, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Amount in ml',
                  suffixText: 'ml',
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.borderSubtle)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.borderSubtle)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF2196F3), width: 1.5)),
                  filled: true,
                  fillColor: AppColors.bgCard,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final ml = int.tryParse(ctrl.text);
                    if (ml != null && ml > 0) _addWater(ml);
                    Navigator.pop(context);
                  },
                  child: Text('Add',
                      style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sleep card ───────────────────────────────────────────────────────────

  Widget _buildSleepCard() {
    final hours = _displaySleepHours;
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    final hasData = hours > 0;

    Color qColor;
    Color qBg;
    switch (_sleepQuality) {
      case 'Good':
        qColor = AppColors.accentGreen;
        qBg = AppColors.accentGreenLight;
        break;
      case 'Fair':
        qColor = AppColors.accentWarning;
        qBg = AppColors.highBg;
        break;
      default:
        qColor = AppColors.accentRed;
        qBg = AppColors.lowHypoBg;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEBFF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bedtime_outlined,
                      size: 16, color: Color(0xFF7B68EE)),
                ),
                const SizedBox(width: 10),
                Text('Sleep',
                    style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ]),
              if (hasData)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: qBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(_sleepQuality,
                      style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: qColor)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              hasData
                  ? Text('${h}h ${m}m',
                      style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary))
                  : Text('No data',
                      style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary)),
              const Spacer(),
              GestureDetector(
                onTap: _showLogSleepSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEBFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Log Sleep',
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF7B68EE))),
                ),
              ),
            ],
          ),
          if (hasData) ...[
            const SizedBox(height: 8),
            Text(
              _connected && _manualSleepHours == null
                  ? 'From Health Connect'
                  : 'Manually logged',
              style: GoogleFonts.outfit(
                  fontSize: 12, color: AppColors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }

  void _showLogSleepSheet() {
    double hoursVal = _displaySleepHours > 0 ? _displaySleepHours : 7.0;
    String quality = _sleepQuality;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSS) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Log Sleep',
                  style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 20),
              Text('Duration: ${hoursVal.toStringAsFixed(1)}h',
                  style: GoogleFonts.outfit(
                      fontSize: 14, color: AppColors.textSecondary)),
              Slider(
                value: hoursVal,
                min: 0,
                max: 12,
                divisions: 24,
                activeColor: const Color(0xFF7B68EE),
                onChanged: (v) => setSS(() => hoursVal = v),
              ),
              const SizedBox(height: 12),
              Text('Quality',
                  style: GoogleFonts.outfit(
                      fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              Row(
                children: ['Poor', 'Fair', 'Good'].map((q) {
                  final sel = quality == q;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => setSS(() => quality = q),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFF7B68EE)
                              : AppColors.bgMuted,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(q,
                            style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: sel
                                    ? Colors.white
                                    : AppColors.textSecondary)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B68EE),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    setState(() {
                      _manualSleepHours = hoursVal;
                      _sleepQuality = quality;
                    });
                    Navigator.pop(ctx);
                  },
                  child: Text('Save',
                      style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ── Activities section ───────────────────────────────────────────────────

  Widget _buildActivitiesSection() {
    // Merge Health Connect workouts + manual entries
    final all = [
      ..._summary.activities.map((a) => _DisplayActivity(
            type: a.type,
            icon: _iconForType(a.type),
            color: _colorForType(a.type),
            duration: a.durationMinutes,
            calories: a.caloriesKcal,
            timeLabel: a.timeLabel,
            fromFit: true,
          )),
      ..._manualActivities.map((a) => _DisplayActivity(
            type: a.type,
            icon: a.icon,
            color: a.color,
            duration: a.duration,
            calories: a.calories,
            timeLabel: a.timeLabel,
            fromFit: false,
          )),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Activities',
                style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            GestureDetector(
              onTap: _showAddActivitySheet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accentGreenLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add,
                        size: 14, color: AppColors.accentGreen),
                    const SizedBox(width: 4),
                    Text('Add',
                        style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentGreen)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (all.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: AppTheme.cardDecoration,
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.directions_run_rounded,
                      size: 36, color: AppColors.textTertiary),
                  const SizedBox(height: 10),
                  Text('No activities logged today',
                      style: GoogleFonts.outfit(
                          fontSize: 14, color: AppColors.textSecondary)),
                ],
              ),
            ),
          )
        else
          ...all.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _activityTile(a),
              )),
      ],
    );
  }

  Widget _activityTile(_DisplayActivity a) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: a.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(a.icon, color: a.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(a.type,
                      style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  if (a.fromFit) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0FE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('HC',
                          style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A73E8))),
                    ),
                  ],
                ]),
                Text(
                    '${a.duration} min  •  ${a.calories} kcal  •  ${a.timeLabel}',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddActivitySheet() {
    final types = [
      _ActivityType('Walking', Icons.directions_walk_rounded, AppColors.accentGreen),
      _ActivityType('Running', Icons.directions_run_rounded, AppColors.accentCoral),
      _ActivityType('Cycling', Icons.directions_bike_rounded, const Color(0xFF7B68EE)),
      _ActivityType('Swimming', Icons.pool_rounded, const Color(0xFF2196F3)),
      _ActivityType('Gym', Icons.fitness_center_rounded, AppColors.accentWarning),
      _ActivityType('Yoga', Icons.self_improvement_rounded, const Color(0xFF66BB6A)),
    ];

    int sel = 0;
    final durationCtrl = TextEditingController(text: '30');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSS) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Log Activity',
                    style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 16),
                Text('Activity Type',
                    style: GoogleFonts.outfit(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: types.asMap().entries.map((e) {
                    final selected = sel == e.key;
                    final at = e.value;
                    return GestureDetector(
                      onTap: () => setSS(() => sel = e.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? at.color.withOpacity(0.15)
                              : AppColors.bgMuted,
                          borderRadius: BorderRadius.circular(20),
                          border: selected
                              ? Border.all(
                                  color: at.color.withOpacity(0.4),
                                  width: 1.5)
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(at.icon, size: 14, color: at.color),
                            const SizedBox(width: 6),
                            Text(at.name,
                                style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? at.color
                                        : AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text('Duration (minutes)',
                    style: GoogleFonts.outfit(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                TextField(
                  controller: durationCtrl,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.outfit(
                      fontSize: 15, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    suffixText: 'min',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.borderSubtle)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.borderSubtle)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.accentGreen, width: 1.5)),
                    filled: true,
                    fillColor: AppColors.bgCard,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final at = types[sel];
                      final dur = int.tryParse(durationCtrl.text) ?? 30;
                      setState(() {
                        _manualActivities.insert(
                          0,
                          _ManualActivity(
                            type: at.name,
                            icon: at.icon,
                            color: at.color,
                            duration: dur,
                            calories: (dur * 5.5).round(),
                            timeLabel: _timeNow(),
                          ),
                        );
                      });
                      Navigator.pop(ctx);
                    },
                    child: Text('Save Activity',
                        style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _formatNumber(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}k';
    }
    return '$n';
  }

  String _timeNow() {
    final now = DateTime.now();
    final h = now.hour > 12
        ? now.hour - 12
        : now.hour == 0
            ? 12
            : now.hour;
    final m = now.minute.toString().padLeft(2, '0');
    return '$h:$m ${now.hour >= 12 ? 'PM' : 'AM'}';
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'walking':
        return Icons.directions_walk_rounded;
      case 'running':
        return Icons.directions_run_rounded;
      case 'cycling':
        return Icons.directions_bike_rounded;
      case 'swimming':
        return Icons.pool_rounded;
      case 'gym':
      case 'strength training':
        return Icons.fitness_center_rounded;
      case 'yoga':
        return Icons.self_improvement_rounded;
      case 'hiit':
        return Icons.bolt_rounded;
      default:
        return Icons.sports_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type.toLowerCase()) {
      case 'walking':
        return AppColors.accentGreen;
      case 'running':
        return AppColors.accentCoral;
      case 'cycling':
        return const Color(0xFF7B68EE);
      case 'swimming':
        return const Color(0xFF2196F3);
      case 'gym':
      case 'strength training':
        return AppColors.accentWarning;
      default:
        return AppColors.textSecondary;
    }
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────

class _ManualActivity {
  final String type;
  final IconData icon;
  final Color color;
  final int duration;
  final int calories;
  final String timeLabel;

  const _ManualActivity({
    required this.type,
    required this.icon,
    required this.color,
    required this.duration,
    required this.calories,
    required this.timeLabel,
  });
}

class _DisplayActivity {
  final String type;
  final IconData icon;
  final Color color;
  final int duration;
  final int calories;
  final String timeLabel;
  final bool fromFit;

  const _DisplayActivity({
    required this.type,
    required this.icon,
    required this.color,
    required this.duration,
    required this.calories,
    required this.timeLabel,
    required this.fromFit,
  });
}

class _ActivityType {
  final String name;
  final IconData icon;
  final Color color;

  const _ActivityType(this.name, this.icon, this.color);
}
