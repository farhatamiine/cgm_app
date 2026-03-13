import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/colors.dart';
import '../services/api_service.dart';
import '../widgets/primary_button.dart';

class LogHypoScreen extends StatefulWidget {
  const LogHypoScreen({super.key});

  @override
  State<LogHypoScreen> createState() => _LogHypoScreenState();
}

class _LogHypoScreenState extends State<LogHypoScreen> {
  final _api = ApiService();
  final _lowestBgController = TextEditingController(text: '52');
  final _durationController = TextEditingController(text: '25');
  final _notesController = TextEditingController();
  DateTime _startedAt = DateTime.now();
  String _treatment = 'Juice';
  bool _isNocturnal = false;
  bool _saving = false;

  final List<String> _treatments = ['Juice', '3 sugar cubes', 'Glucose tablets', 'Other'];

  @override
  void dispose() {
    _lowestBgController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final lowest = double.tryParse(_lowestBgController.text);
    if (lowest == null || lowest > 70) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lowest BG must be ≤ 70 mg/dL', style: GoogleFonts.outfit()),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final duration = int.tryParse(_durationController.text);
      await _api.logHypo(
        lowestValue: lowest,
        startedAt: _startedAt,
        durationMin: duration,
        treatedWith: _treatment,
        notes: _notesController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hypo event logged successfully', style: GoogleFonts.outfit()),
            backgroundColor: AppColors.accentGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e', style: GoogleFonts.outfit()),
            backgroundColor: AppColors.accentRed),
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
                    const SizedBox(height: 24),
                    _buildWarningBanner(),
                    const SizedBox(height: 24),
                    _buildLowestBg(),
                    const SizedBox(height: 24),
                    _buildStartTime(),
                    const SizedBox(height: 24),
                    _buildDuration(),
                    const SizedBox(height: 24),
                    _buildTreatment(),
                    const SizedBox(height: 24),
                    _buildNocturnalToggle(),
                    const SizedBox(height: 24),
                    _buildNotesSection(),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Save Hypo Event',
                      onPressed: _save,
                      isLoading: _saving,
                      color: AppColors.accentRed,
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
          Text('Log Hypo', style: GoogleFonts.outfit(
            fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.lowHypoBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentRed),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.accentRed, size: 20),
          const SizedBox(width: 10),
          Text('Hypoglycaemia Event', style: GoogleFonts.outfit(
            fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accentRed)),
        ],
      ),
    );
  }

  Widget _buildLowestBg() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Lowest BG Reached', style: GoogleFonts.outfit(
          fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        TextField(
          controller: _lowestBgController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.outfit(
            fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.accentRed),
          decoration: InputDecoration(
            hintText: '52',
            hintStyle: GoogleFonts.outfit(color: AppColors.textTertiary),
            suffixText: 'mg/dL',
            suffixStyle: GoogleFonts.outfit(color: AppColors.textTertiary, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildStartTime() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Start Time', style: GoogleFonts.outfit(
          fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () async {
            final time = await showTimePicker(
              context: context, initialTime: TimeOfDay.fromDateTime(_startedAt));
            if (time != null) {
              setState(() {
                _startedAt = DateTime(
                  _startedAt.year, _startedAt.month, _startedAt.day,
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
                Text(DateFormat('h:mm a — MMM d').format(_startedAt),
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

  Widget _buildDuration() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Duration (minutes)', style: GoogleFonts.outfit(
          fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        TextField(
          controller: _durationController,
          keyboardType: TextInputType.number,
          style: GoogleFonts.outfit(fontSize: 15, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: GoogleFonts.outfit(color: AppColors.textTertiary),
            suffixText: 'min',
            suffixStyle: GoogleFonts.outfit(color: AppColors.textTertiary, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildTreatment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Treatment Used', style: GoogleFonts.outfit(
          fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _treatments.map((t) {
            final selected = t == _treatment;
            return GestureDetector(
              onTap: () => setState(() => _treatment = t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.accentCoral : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  border: selected ? null : Border.all(color: AppColors.borderSubtle),
                ),
                child: Text(t, style: GoogleFonts.outfit(
                  fontSize: 13, fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : AppColors.textSecondary)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNocturnalToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Was this overnight?', style: GoogleFonts.outfit(
            fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          Switch(
            value: _isNocturnal,
            onChanged: (v) => setState(() => _isNocturnal = v),
            activeThumbColor: AppColors.accentCoral,
          ),
        ],
      ),
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
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}
