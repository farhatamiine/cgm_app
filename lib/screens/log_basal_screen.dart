import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/colors.dart';
import '../core/theme.dart';
import '../services/offline_cache_service.dart';
import '../widgets/primary_button.dart';

class LogBasalScreen extends StatefulWidget {
  const LogBasalScreen({super.key});

  @override
  State<LogBasalScreen> createState() => _LogBasalScreenState();
}

class _LogBasalScreenState extends State<LogBasalScreen> {
  final _cache = OfflineCacheService();

  double _units = 18;
  String _insulin = 'Glargine';
  String _timingLabel = 'Night'; // Night | Morning (API field)
  final _notesController = TextEditingController();
  bool _saving = false;

  // Actual clock time the injection was given (default: now)
  DateTime _loggedAt = DateTime.now();

  List<Map<String, dynamic>> _todayBasals = [];
  double _todayTotal = 0;

  final List<String> _insulinTypes = ['Glargine', 'Degludec', 'Tresiba'];
  final List<String> _timingOptions = ['Night', 'Morning'];

  static const Color _basalColor = Color(0xFF7B68EE);
  static const Color _basalLight = Color(0xFFEEEBFF);

  @override
  void initState() {
    super.initState();
    _loadDailyLog();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _loadDailyLog() {
    setState(() {
      _todayBasals = _cache.getTodayBasals();
      _todayTotal = _cache.getTodayTotalBasal();
    });
  }

  Future<void> _pickTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _loggedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_loggedAt),
    );
    if (time == null || !mounted) return;
    final picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      _loggedAt = picked;
      // Auto-set timing label based on hour
      _timingLabel = picked.hour >= 18 || picked.hour < 6 ? 'Night' : 'Morning';
    });
  }

  Future<void> _save() async {
    if (_units <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Units must be greater than 0',
              style: GoogleFonts.outfit()),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _cache.logBasal(
        units: _units,
        insulin: _insulin,
        time: _timingLabel,
        notes: _notesController.text,
        loggedAt: _loggedAt,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Basal logged: ${_units.round()} units of $_insulin',
                style: GoogleFonts.outfit()),
            backgroundColor: AppColors.accentGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.outfit()),
            backgroundColor: AppColors.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildTodayLogPanel(),
                    const SizedBox(height: 24),
                    _buildTimePicker(),
                    const SizedBox(height: 24),
                    _buildInsulinName(),
                    const SizedBox(height: 24),
                    _buildUnitsStepper(),
                    const SizedBox(height: 24),
                    _buildTiming(),
                    const SizedBox(height: 24),
                    _buildNotesSection(),
                    const SizedBox(height: 28),
                    PrimaryButton(
                      label: 'Save Basal',
                      onPressed: _save,
                      isLoading: _saving,
                      color: _basalColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back,
                size: 24, color: AppColors.textPrimary),
          ),
          Text('Log Basal',
              style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildTodayLogPanel() {
    if (_todayBasals.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _basalLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _basalColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Today's Basal",
                  style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _basalColor)),
              Text('${_todayTotal.toStringAsFixed(0)} u total',
                  style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _basalColor)),
            ],
          ),
          const SizedBox(height: 8),
          ..._todayBasals.map((b) {
            final t = DateFormat('HH:mm')
                .format(DateTime.parse(b['time'] as String));
            final units = (b['units'] as num).toStringAsFixed(0);
            final insulin = (b['insulin'] ?? '').toString();
            final pending = b['pending'] == true;
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Text(t,
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(width: 8),
                  Text('${units}u',
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(width: 6),
                  Text(insulin,
                      style: GoogleFonts.outfit(
                          fontSize: 11, color: AppColors.textTertiary)),
                  if (pending) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accentWarning.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('pending sync',
                          style: GoogleFonts.outfit(
                              fontSize: 10,
                              color: AppColors.accentWarning)),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimePicker() {
    final isNow = DateTime.now().difference(_loggedAt).inMinutes.abs() < 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Time of Injection',
            style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickTime,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isNow ? AppColors.borderSubtle : _basalColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isNow
                          ? 'Now'
                          : DateFormat('HH:mm  \u2014  MMM d')
                              .format(_loggedAt),
                      style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary),
                    ),
                    if (!isNow)
                      Text('Logging missed injection',
                          style: GoogleFonts.outfit(
                              fontSize: 11, color: _basalColor)),
                  ],
                ),
                const Icon(Icons.access_time_rounded,
                    size: 18, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInsulinName() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Insulin Name',
            style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        Row(
          children: _insulinTypes.map((type) {
            final selected = type == _insulin;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _insulin = type),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? _basalColor : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: selected
                        ? null
                        : Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Text(type,
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildUnitsStepper() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Text('Units',
              style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stepperBtn(Icons.remove, () {
                if (_units > 1)
                  setState(() => _units = (_units - 1).clamp(1, 60));
              }, AppColors.bgMuted, AppColors.textPrimary),
              const SizedBox(width: 24),
              Text(_units.round().toString(),
                  style: GoogleFonts.outfit(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(width: 24),
              _stepperBtn(Icons.add, () {
                if (_units < 60)
                  setState(() => _units = (_units + 1).clamp(1, 60));
              }, _basalColor, Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepperBtn(
      IconData icon, VoidCallback onTap, Color bg, Color fg) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: fg, size: 20),
      ),
    );
  }

  Widget _buildTiming() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Injection Period',
            style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Text('Auto-set from selected time, or override below',
            style: GoogleFonts.outfit(
                fontSize: 12, color: AppColors.textTertiary)),
        const SizedBox(height: 10),
        Row(
          children: _timingOptions.map((opt) {
            final selected = opt == _timingLabel;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _timingLabel = opt),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? _basalColor : AppColors.bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: selected
                          ? null
                          : Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Center(
                      child: Text(opt,
                          style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textSecondary)),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notes',
            style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        TextField(
          controller: _notesController,
          maxLines: 3,
          style: GoogleFonts.outfit(
              fontSize: 15, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Add a note...',
            hintStyle:
                GoogleFonts.outfit(color: AppColors.textTertiary),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}
