import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/colors.dart';
import '../core/theme.dart';
import '../services/juggluco_service.dart';
import '../services/offline_cache_service.dart';
import '../services/user_profile_service.dart';
import '../widgets/primary_button.dart';

class LogBolusScreen extends StatefulWidget {
  const LogBolusScreen({super.key});

  @override
  State<LogBolusScreen> createState() => _LogBolusScreenState();
}

class _LogBolusScreenState extends State<LogBolusScreen> {
  final _cache = OfflineCacheService();
  final _juggluco = JugglucoService();
  final _profile = UserProfileService();

  double _units = 4.5;
  String _bolusType = 'meal';
  String _mealType = 'high_gi';
  final _carbsController = TextEditingController(text: '45');
  final _notesController = TextEditingController();
  double? _glucoseAtInjection;
  bool _saving = false;
  bool _fetchingGlucose = false;

  // Time of injection — default now, user can pick past time for missed injections
  DateTime _loggedAt = DateTime.now();

  List<Map<String, dynamic>> _todayBoluses = [];
  double _todayTotal = 0;

  final List<String> _bolusTypes = ['manual', 'meal', 'correction'];
  final List<String> _bolusTypeLabels = ['Manual', 'Meal', 'Correction'];
  final List<Map<String, String>> _mealTypes = [
    {'value': 'low_gi', 'label': 'Low GI'},
    {'value': 'medium_gi', 'label': 'Medium GI'},
    {'value': 'high_gi', 'label': 'High GI'},
  ];

  @override
  void initState() {
    super.initState();
    _loadDailyLog();
    _fetchCurrentGlucose();
  }

  @override
  void dispose() {
    _carbsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _loadDailyLog() {
    setState(() {
      _todayBoluses = _cache.getTodayBoluses();
      _todayTotal = _cache.getTodayTotalBolus();
    });
  }

  Future<void> _fetchCurrentGlucose() async {
    if (!_profile.jugglucoEnabled) return;
    setState(() => _fetchingGlucose = true);
    final reading = await _juggluco.fetchCurrent();
    if (mounted && reading != null) {
      setState(() => _glucoseAtInjection = reading.value);
    }
    if (mounted) setState(() => _fetchingGlucose = false);
  }

  Future<void> _fetchGlucoseAtTime(DateTime time) async {
    if (!_profile.jugglucoEnabled) return;
    setState(() => _fetchingGlucose = true);
    final reading = await _juggluco.fetchAtTime(time);
    if (mounted && reading != null) {
      setState(() => _glucoseAtInjection = reading.value);
    }
    if (mounted) setState(() => _fetchingGlucose = false);
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
    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => _loggedAt = picked);
    // Auto-fetch glucose reading at that time from Juggluco history
    await _fetchGlucoseAtTime(picked);
  }

  Future<void> _save() async {
    if (_units <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Units must be greater than 0', style: GoogleFonts.outfit()),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _cache.logBolus(
        units: _units,
        bolusType: _bolusType,
        mealType: _bolusType == 'meal' ? _mealType : null,
        glucoseAtInjection: _glucoseAtInjection,
        notes: _notesController.text,
        loggedAt: _loggedAt,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bolus logged: ${_units.toStringAsFixed(1)} units',
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
                    _buildCurrentGlucoseCard(),
                    const SizedBox(height: 24),
                    _buildUnitsStepper(),
                    const SizedBox(height: 24),
                    _buildBolusType(),
                    const SizedBox(height: 24),
                    if (_bolusType == 'meal') ...[
                      _buildMealType(),
                      const SizedBox(height: 24),
                      _buildCarbsInput(),
                      const SizedBox(height: 24),
                    ],
                    _buildNotesSection(),
                    const SizedBox(height: 28),
                    PrimaryButton(
                      label: 'Save Bolus',
                      onPressed: _save,
                      isLoading: _saving,
                      color: AppColors.accentCoral,
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
            child: const Icon(Icons.arrow_back, size: 24, color: AppColors.textPrimary),
          ),
          Text('Log Bolus',
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
    if (_todayBoluses.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentCoralLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentCoral.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Today's Boluses",
                  style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentCoral)),
              Text('${_todayTotal.toStringAsFixed(1)} u total',
                  style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentCoral)),
            ],
          ),
          const SizedBox(height: 8),
          ..._todayBoluses.map((b) {
            final t = DateFormat('HH:mm')
                .format(DateTime.parse(b['time'] as String));
            final units = (b['units'] as num).toStringAsFixed(1);
            final type = (b['type'] ?? '').toString();
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
                  Text(type,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isNow
                      ? AppColors.borderSubtle
                      : AppColors.accentCoral),
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
                              fontSize: 11, color: AppColors.accentCoral)),
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

  Widget _buildCurrentGlucoseCard() {
    final hasJuggluco = _profile.jugglucoEnabled;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Glucose at Injection',
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                if (_fetchingGlucose)
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.accentCoral),
                  )
                else if (_glucoseAtInjection != null)
                  Text(
                      '${_glucoseAtInjection!.toStringAsFixed(0)} mg/dL',
                      style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentCoral))
                else
                  Text(
                      hasJuggluco
                          ? 'Tap refresh to fetch'
                          : 'Enable Juggluco in Profile',
                      style: GoogleFonts.outfit(
                          fontSize: 13, color: AppColors.textTertiary)),
              ],
            ),
          ),
          if (hasJuggluco)
            GestureDetector(
              onTap: () => _fetchGlucoseAtTime(_loggedAt),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accentCoralLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.refresh_rounded,
                    size: 18, color: AppColors.accentCoral),
              ),
            ),
        ],
      ),
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
                if (_units > 0.5)
                  setState(() => _units = (_units - 0.5).clamp(0.5, 30));
              }, AppColors.bgMuted, AppColors.textPrimary),
              const SizedBox(width: 24),
              Text(_units.toStringAsFixed(1),
                  style: GoogleFonts.outfit(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(width: 24),
              _stepperBtn(Icons.add, () {
                if (_units < 30)
                  setState(() => _units = (_units + 0.5).clamp(0.5, 30));
              }, AppColors.accentCoral, Colors.white),
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

  Widget _buildBolusType() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bolus Type',
            style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        Row(
          children: List.generate(_bolusTypes.length, (i) {
            final selected = _bolusTypes[i] == _bolusType;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _bolusType = _bolusTypes[i]),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accentCoral
                        : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: selected
                        ? null
                        : Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Text(_bolusTypeLabels[i],
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary)),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildMealType() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Meal Type',
            style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        Row(
          children: _mealTypes.map((m) {
            final selected = m['value'] == _mealType;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _mealType = m['value']!),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accentCoral
                        : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: selected
                        ? null
                        : Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Text(m['label']!,
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

  Widget _buildCarbsInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Carbs (grams)',
            style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        TextField(
          controller: _carbsController,
          keyboardType: TextInputType.number,
          style: GoogleFonts.outfit(
              fontSize: 15, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle:
                GoogleFonts.outfit(color: AppColors.textTertiary),
          ),
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
