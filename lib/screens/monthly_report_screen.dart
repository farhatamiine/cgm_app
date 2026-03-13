import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/colors.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../widgets/primary_button.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _report;
  bool _loading = true;
  bool _downloading = false;
  String? _error;
  int _selectedPeriod = 0;
  final List<String> _periods = ['1 Month', '2 Months', '3 Months'];
  final List<int> _periodDays = [30, 60, 90];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getMonthlyReport(days: _periodDays[_selectedPeriod]);
      setState(() { _report = data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _downloadPdf() async {
    final date = _report?['generated_at'];
    if (date == null) return;
    setState(() => _downloading = true);
    final url = _api.pdfDownloadUrl(date);
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open PDF: $e', style: GoogleFonts.outfit()),
            backgroundColor: AppColors.accentRed),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
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
            _buildPeriodSelector(),
            const SizedBox(height: 20),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accentGreen))
                  : _error != null
                      ? Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.accentRed, size: 48),
                            const SizedBox(height: 12),
                            Text('Could not load report',
                              style: GoogleFonts.outfit(color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            TextButton(onPressed: _loadReport,
                              child: Text('Retry', style: GoogleFonts.outfit(
                                color: AppColors.accentGreen, fontWeight: FontWeight.w600))),
                          ]))
                      : RefreshIndicator(
                          onRefresh: _loadReport,
                          color: AppColors.accentGreen,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            child: Column(
                              children: [
                                _buildSummaryGrid(),
                                const SizedBox(height: 20),
                                _buildWeeklyTrends(),
                                const SizedBox(height: 20),
                                _buildBasalSection(),
                                const SizedBox(height: 12),
                                _buildBolusSection(),
                                const SizedBox(height: 12),
                                _buildHypoSection(),
                                const SizedBox(height: 20),
                                _buildAiAnalysis(),
                                const SizedBox(height: 20),
                                PrimaryButton(
                                  label: 'Download PDF Report',
                                  onPressed: _report?['pdf_url'] != null ? _downloadPdf : null,
                                  isLoading: _downloading,
                                ),
                              ],
                            ),
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
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, size: 24, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 16),
          Text('Monthly Report', style: GoogleFonts.outfit(
            fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 40,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(
            color: AppColors.shadowColorDark, blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: Row(
          children: List.generate(_periods.length, (i) {
            final selected = i == _selectedPeriod;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedPeriod = i);
                  _loadReport();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accentCoral : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(_periods[i], style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? Colors.white : AppColors.textSecondary)),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSummaryGrid() {
    final tir = (_report?['overall_tir'] ?? 0.0).toDouble();
    final avg = (_report?['overall_avg_glucose'] ?? 0.0).toStringAsFixed(0);
    final gmi = (_report?['overall_gmi'] ?? 0.0).toStringAsFixed(1);
    final cv = (_report?['overall_cv'] ?? 0.0).toStringAsFixed(1);

    return Column(
      children: [
        Row(children: [
          Expanded(child: _summaryCard('Time in Range', '${tir.toStringAsFixed(1)}%',
            AppColors.accentGreenLight, AppColors.accentGreen)),
          const SizedBox(width: 10),
          Expanded(child: _summaryCard('Avg Glucose', '$avg mg/dL',
            AppColors.bgMuted, AppColors.textPrimary)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _summaryCard('GMI', '$gmi%',
            AppColors.highBg, AppColors.accentWarning)),
          const SizedBox(width: 10),
          Expanded(child: _summaryCard('CV%', '$cv%',
            AppColors.accentCoralLight, AppColors.accentCoral)),
        ]),
      ],
    );
  }

  Widget _summaryCard(String label, String value, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.outfit(
            fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.outfit(
            fontSize: 20, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }

  Widget _buildWeeklyTrends() {
    final trends = _report?['weekly_trends'] as List?;
    if (trends == null || trends.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly Trends', style: GoogleFonts.outfit(
            fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          ...trends.map((week) {
            final w = week['week'];
            final tir = (week['tir'] ?? 0.0).toDouble();
            final avg = (week['avg_glucose'] ?? 0.0).toStringAsFixed(0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.accentGreenLight,
                    borderRadius: BorderRadius.circular(8)),
                  child: Center(
                    child: Text('W$w', style: GoogleFonts.outfit(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: AppColors.accentGreen)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        flex: tir.round().clamp(1, 100),
                        child: Container(height: 6, decoration: BoxDecoration(
                          color: AppColors.accentGreen,
                          borderRadius: BorderRadius.circular(3))),
                      ),
                      Expanded(
                        flex: (100 - tir.round()).clamp(1, 100) as int,
                        child: Container(height: 6, decoration: BoxDecoration(
                          color: AppColors.bgMuted,
                          borderRadius: BorderRadius.circular(3))),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text('TIR ${tir.toStringAsFixed(0)}%  •  Avg $avg mg/dL',
                      style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary)),
                  ]),
                ),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBasalSection() {
    final basal = _report?['basal'];
    if (basal == null) return const SizedBox.shrink();
    return _sectionRow(
      Icons.medication_outlined, AppColors.accentGreenLight, AppColors.accentGreen,
      'Basal',
      '${basal['total_injections']} doses  •  avg ${(basal['avg_units'] ?? 0).toStringAsFixed(1)}u  •  ${basal['most_used_insulin'] ?? 'N/A'}',
      basal['consistency_flag'] ?? '',
    );
  }

  Widget _buildBolusSection() {
    final bolus = _report?['bolus'];
    if (bolus == null) return const SizedBox.shrink();
    return _sectionRow(
      Icons.vaccines_outlined, AppColors.accentCoralLight, AppColors.accentCoral,
      'Bolus',
      '${bolus['total_boluses']} doses  •  avg ${(bolus['avg_units'] ?? 0).toStringAsFixed(1)}u  •  ${bolus['most_common_meal_type'] ?? 'N/A'}',
      '${bolus['meal_boluses']} meal  •  ${bolus['correction_boluses']} correction',
    );
  }

  Widget _buildHypoSection() {
    final hypo = _report?['hypo'];
    if (hypo == null) return const SizedBox.shrink();
    return _sectionRow(
      Icons.warning_amber_rounded, AppColors.lowHypoBg, AppColors.accentRed,
      'Hypo Events',
      '${hypo['total_events']} events  •  avg low ${(hypo['avg_lowest_value'] ?? 0).toStringAsFixed(0)} mg/dL',
      '${hypo['nocturnal_count']} nocturnal  •  ${hypo['daytime_count']} daytime',
    );
  }

  Widget _sectionRow(IconData icon, Color iconBg, Color iconFg,
      String title, String sub1, String sub2) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(
          color: AppColors.shadowColorDark, blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconFg, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.outfit(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(sub1, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
            Text(sub2, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textTertiary)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildAiAnalysis() {
    final text = _report?['ai_analysis'] ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.accentCoral),
            const SizedBox(width: 8),
            Text('AI Clinical Analysis', style: GoogleFonts.outfit(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 10),
          Text(text, style: GoogleFonts.outfit(
            fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
        ],
      ),
    );
  }
}
