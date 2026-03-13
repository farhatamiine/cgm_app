import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/colors.dart';
import '../core/theme.dart';
import '../widgets/primary_button.dart';

class LogGlucoseScreen extends StatefulWidget {
  const LogGlucoseScreen({super.key});

  @override
  State<LogGlucoseScreen> createState() => _LogGlucoseScreenState();
}

class _LogGlucoseScreenState extends State<LogGlucoseScreen> {
  double _glucoseValue = 118;
  String _selectedMealTag = 'Before Breakfast';
  final _notesController = TextEditingController();
  DateTime _selectedTime = DateTime.now();
  bool _saving = false;

  final List<String> _mealTags = [
    'Before Breakfast',
    'After Breakfast',
    'Before Lunch',
    'After Lunch',
    'Before Dinner',
    'After Dinner',
    'Fasting',
    'Bedtime',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Color get _glucoseColor {
    if (_glucoseValue < 70) return AppColors.accentRed;
    if (_glucoseValue > 180) return AppColors.accentWarning;
    return AppColors.accentGreen;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Glucose reading saved: ${_glucoseValue.round()} mg/dL',
              style: GoogleFonts.outfit()),
          backgroundColor: AppColors.accentGreen,
        ),
      );
      Navigator.pop(context);
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
                    const SizedBox(height: 28),
                    _buildGlucoseInput(),
                    const SizedBox(height: 28),
                    _buildMealTags(),
                    const SizedBox(height: 28),
                    _buildTimeSection(),
                    const SizedBox(height: 28),
                    _buildNotesSection(),
                    const SizedBox(height: 28),
                    PrimaryButton(
                      label: 'Save Reading',
                      onPressed: _save,
                      isLoading: _saving,
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
          Text('Log Reading', style: GoogleFonts.outfit(
            fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildGlucoseInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Text('Glucose Level', style: GoogleFonts.outfit(
            fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_glucoseValue.round().toString(),
                style: GoogleFonts.outfit(
                  fontSize: 48, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('mg/dL', style: GoogleFonts.outfit(
                  fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _glucoseColor,
              inactiveTrackColor: AppColors.borderSubtle,
              thumbColor: Colors.white,
              overlayColor: _glucoseColor.withValues(alpha: 0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              trackHeight: 6,
            ),
            child: Slider(
              value: _glucoseValue,
              min: 40,
              max: 400,
              onChanged: (v) => setState(() => _glucoseValue = v),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('40', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textTertiary)),
              Text('400', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealTags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Meal Tag', style: GoogleFonts.outfit(
          fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _mealTags.map((tag) {
            final selected = tag == _selectedMealTag;
            return GestureDetector(
              onTap: () => setState(() => _selectedMealTag = tag),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.accentCoral : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  border: selected ? null : Border.all(color: AppColors.borderSubtle),
                ),
                child: Text(tag, style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : AppColors.textSecondary,
                )),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Time', style: GoogleFonts.outfit(
          fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () async {
            final time = await showTimePicker(
              context: context, initialTime: TimeOfDay.fromDateTime(_selectedTime));
            if (time != null) {
              setState(() {
                _selectedTime = DateTime(
                  _selectedTime.year, _selectedTime.month, _selectedTime.day,
                  time.hour, time.minute);
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('h:mm a — MMM d').format(_selectedTime),
                  style: GoogleFonts.outfit(
                    fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                const Icon(Icons.access_time_rounded, size: 18, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notes', style: GoogleFonts.outfit(
          fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        TextField(
          controller: _notesController,
          maxLines: 3,
          style: GoogleFonts.outfit(fontSize: 15, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Add a note...',
            hintStyle: GoogleFonts.outfit(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.bgCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.accentCoral, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}
