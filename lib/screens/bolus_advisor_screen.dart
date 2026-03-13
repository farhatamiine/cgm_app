import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../widgets/primary_button.dart';
import 'log_bolus_screen.dart';

class BolusAdvisorScreen extends StatefulWidget {
  const BolusAdvisorScreen({super.key});

  @override
  State<BolusAdvisorScreen> createState() => _BolusAdvisorScreenState();
}

class _BolusAdvisorScreenState extends State<BolusAdvisorScreen> {
  final _api = ApiService();
  String _selectedMealType = 'medium_gi';
  Map<String, dynamic>? _result;
  bool _loading = false;
  String? _error;

  final List<Map<String, String>> _mealTypes = [
    {'value': 'low_gi', 'label': 'Low GI'},
    {'value': 'medium_gi', 'label': 'Medium GI'},
    {'value': 'high_gi', 'label': 'High GI'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchAdvice();
  }

  Future<void> _fetchAdvice() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getBolustiming(mealType: _selectedMealType);
      setState(() { _result = data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
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
                    _buildMealGiSelector(),
                    const SizedBox(height: 28),
                    if (_loading)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: AppColors.accentCoral),
                      ))
                    else if (_error != null)
                      _buildErrorCard()
                    else if (_result != null)
                      _buildResultCard(),
                    const SizedBox(height: 28),
                    if (_result != null)
                      PrimaryButton(
                        label: 'Log This Bolus',
                        onPressed: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const LogBolusScreen())),
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
          Text('Smart Bolus Timing', style: GoogleFonts.outfit(
            fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildMealGiSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Meal GI', style: GoogleFonts.outfit(
          fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        Row(
          children: _mealTypes.map((m) {
            final selected = m['value'] == _selectedMealType;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedMealType = m['value']!);
                  _fetchAdvice();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accentCoral : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: selected ? null : Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Text(m['label']!, style: GoogleFonts.outfit(
                    fontSize: 13, fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : AppColors.textSecondary)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildResultCard() {
    final minutes = _result!['inject_minutes_before'] as int;
    final message = _result!['message'] as String;
    final warning = _result!['warning'] as String?;

    String timing;
    if (minutes < 0) {
      timing = 'Do not bolus';
    } else if (minutes == 0) {
      timing = 'Inject right before eating';
    } else {
      timing = 'Inject $minutes min before eating';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Icon(
            minutes < 0 ? Icons.cancel_outlined : Icons.timer_outlined,
            size: 32,
            color: minutes < 0 ? AppColors.accentRed : AppColors.accentCoral,
          ),
          const SizedBox(height: 16),
          Text(timing,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Text(message,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
          if (warning != null && warning.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.highBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded,
                  size: 16, color: AppColors.accentWarning),
                const SizedBox(width: 8),
                Expanded(child: Text(warning, style: GoogleFonts.outfit(
                  fontSize: 12, color: AppColors.accentWarning))),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.accentRed),
          const SizedBox(height: 12),
          Text('Could not fetch advice', style: GoogleFonts.outfit(
            fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _fetchAdvice,
            child: Text('Try again', style: GoogleFonts.outfit(
              color: AppColors.accentGreen, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
