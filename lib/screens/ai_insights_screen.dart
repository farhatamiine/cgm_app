import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/colors.dart';
import '../core/theme.dart';
import '../services/api_service.dart';

class AiInsightsScreen extends StatefulWidget {
  const AiInsightsScreen({super.key});

  @override
  State<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends State<AiInsightsScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _insight;
  bool _loading = false;
  String? _error;
  final int _days = 7;

  @override
  void initState() {
    super.initState();
    _fetchInsight();
  }

  Future<void> _fetchInsight() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getAiInsights(days: _days);
      setState(() { _insight = data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
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
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppColors.accentCoral),
                      SizedBox(height: 16),
                    ],
                  ),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.accentRed, size: 48),
                        const SizedBox(height: 12),
                        Text('Could not generate insight',
                          style: GoogleFonts.outfit(color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        TextButton(onPressed: _fetchInsight,
                          child: Text('Retry', style: GoogleFonts.outfit(
                            color: AppColors.accentGreen, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                ),
              )
            else if (_insight != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildDateRange(),
                    const SizedBox(height: 24),
                    _buildInsightCard(),
                    const SizedBox(height: 24),
                    _buildGenerateButton(),
                    const SizedBox(height: 16),
                    _buildDisclaimer(),
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
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.accentGreenLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
              size: 20, color: AppColors.accentGreen),
          ),
          const SizedBox(width: 12),
          Text('AI Insights', style: GoogleFonts.outfit(
            fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const Spacer(),
          if (_insight?['cached'] == true)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentGreenLight,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text('Cached', style: GoogleFonts.outfit(
                fontSize: 11, color: AppColors.accentGreen, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _buildDateRange() {
    final date = _insight?['date'];
    final endDate = date != null ? DateFormat('MMM d').format(DateTime.parse(date)) : '';
    final startDate = date != null
        ? DateFormat('MMM d').format(DateTime.parse(date).subtract(Duration(days: _days - 1)))
        : '';

    return Text(
      'Last $_days days  •  $startDate – $endDate',
      style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textTertiary),
    );
  }

  Widget _buildInsightCard() {
    final text = _insight?['insight'] ?? '';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.accentCoral),
            const SizedBox(width: 8),
            Text('Weekly Analysis', style: GoogleFonts.outfit(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 16),
          Text(text, style: GoogleFonts.outfit(
            fontSize: 14, color: AppColors.textPrimary, height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    return GestureDetector(
      onTap: _fetchInsight,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accentCoral, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.refresh_rounded, size: 16, color: AppColors.accentCoral),
            const SizedBox(width: 8),
            Text('Generate New Insight', style: GoogleFonts.outfit(
              fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.accentCoral)),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'Not medical advice. Always consult your healthcare provider before making changes to your treatment plan.',
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textTertiary, height: 1.4),
      ),
    );
  }
}
