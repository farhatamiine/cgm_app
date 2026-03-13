import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../widgets/metric_card.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _api = ApiService();
  int _selectedPeriod = 0; // 0=7d, 1=14d, 2=30d
  final List<String> _periods = ['7 Days', '14 Days', '30 Days'];
  final List<String> _periodValues = ['7', '14', '30'];
  Map<String, dynamic>? _report;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getGlucoseReport(days: _periodValues[_selectedPeriod]);
      setState(() { _report = data; _loading = false; });
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildSegmentControl(),
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
                                _buildPatternChart(),
                                const SizedBox(height: 20),
                                _buildMetricsGrid(),
                                const SizedBox(height: 20),
                                _buildTirSection(),
                                const SizedBox(height: 20),
                                _buildVariabilityCard(),
                                const SizedBox(height: 20),
                                _buildDawnPhenomenon(),
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
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Text('Statistics', style: GoogleFonts.outfit(
        fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    );
  }

  Widget _buildSegmentControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(
            color: AppColors.shadowColorDark, blurRadius: 8, offset: Offset(0, 2))],
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
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Text(_periods[i], style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? Colors.white : AppColors.textSecondary,
                    )),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildPatternChart() {
    final patterns = _report?['patterns'];
    if (patterns == null) return const SizedBox.shrink();

    final data = [
      ('Morning', (patterns['morning']?['avg'] ?? 0 as num).toDouble(), AppColors.accentCoral),
      ('Afternoon', (patterns['afternoon']?['avg'] ?? 0 as num).toDouble(), AppColors.accentWarning),
      ('Evening', (patterns['evening']?['avg'] ?? 0 as num).toDouble(), AppColors.accentGreen),
      ('Night', (patterns['night']?['avg'] ?? 0 as num).toDouble(), const Color(0xFF7B68EE)),
    ];

    final maxVal = data.map((d) => d.$2).fold(0.0, (a, b) => a > b ? a : b);
    final chartMax = (maxVal * 1.25).clamp(100.0, 400.0);

    final barGroups = data.asMap().entries.map((entry) {
      final i = entry.key;
      final d = entry.value;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: d.$2 > 0 ? d.$2 : 0,
            color: d.$3,
            width: 32,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
          ),
        ],
      );
    }).toList();

    final labels = data.map((d) => d.$1).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Daily Patterns',
                  style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              Text('avg mg/dL',
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: chartMax,
                minY: 0,
                barGroups: barGroups,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 50,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.borderSubtle,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[index],
                            style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppColors.textTertiary),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.textPrimary,
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.round()} mg/dL',
                        GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    final stats = _report?['stats'];
    final avg = (stats?['stats']?['average'] ?? 0.0).toStringAsFixed(0);
    final gmi = (stats?['stats']?['gmi'] ?? 0.0).toStringAsFixed(1);
    final variability = _report?['variability'];
    final highest = (variability?['highest'] ?? 0.0).toStringAsFixed(0);
    final lowest = (variability?['lowest'] ?? 0.0).toStringAsFixed(0);

    return Column(
      children: [
        Row(children: [
          Expanded(child: MetricCard(label: 'Average', value: avg)),
          const SizedBox(width: 10),
          Expanded(child: MetricCard(label: 'GMI (Est. A1c)', value: gmi, unit: '%')),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: MetricCard(label: "Period High", value: highest)),
          const SizedBox(width: 10),
          Expanded(child: MetricCard(label: "Period Low", value: lowest)),
        ]),
      ],
    );
  }

  Widget _buildTirSection() {
    final ranges = _report?['stats']?['ranges'];
    final tir = (ranges?['tir'] ?? 0.0).toDouble();
    final tar = (ranges?['tar'] ?? 0.0).toDouble();
    final tbr = (ranges?['tbr'] ?? 0.0).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Time in Range', style: GoogleFonts.outfit(
            fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: tir.round().clamp(1, 100),
                child: Container(
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppColors.accentGreen,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(6), bottomLeft: Radius.circular(6)),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                flex: tar.round().clamp(1, 100),
                child: Container(height: 12, color: AppColors.accentWarning),
              ),
              const SizedBox(width: 2),
              Expanded(
                flex: tbr.round().clamp(1, 100),
                child: Container(
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppColors.accentRed,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(6), bottomRight: Radius.circular(6)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _tirRow(AppColors.accentGreen, 'In Range', '${tir.toStringAsFixed(1)}%'),
              const SizedBox(width: 16),
              _tirRow(AppColors.accentWarning, 'High', '${tar.toStringAsFixed(1)}%'),
              const SizedBox(width: 16),
              _tirRow(AppColors.accentRed, 'Low', '${tbr.toStringAsFixed(1)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tirRow(Color color, String label, String value) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(
        color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text('$label $value', style: GoogleFonts.outfit(
        fontSize: 12, color: AppColors.textSecondary)),
    ]);
  }

  Widget _buildVariabilityCard() {
    final v = _report?['variability'];
    if (v == null) return const SizedBox.shrink();
    final cv = (v['cv'] ?? 0.0).toDouble();
    final flag = v['flag'] ?? '';
    final isStable = flag == 'STABLE';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: isStable ? AppColors.accentGreenLight : AppColors.highBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('CV% Variability', style: GoogleFonts.outfit(
            fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          Row(children: [
            Text('${cv.toStringAsFixed(1)}%', style: GoogleFonts.outfit(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: isStable ? AppColors.accentGreen : AppColors.accentWarning)),
            const SizedBox(width: 4),
            Icon(
              isStable ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              size: 16,
              color: isStable ? AppColors.accentGreen : AppColors.accentWarning,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildDawnPhenomenon() {
    final dp = _report?['dawn_phenomenon'];
    if (dp == null) return const SizedBox.shrink();
    final flag = dp['flag'] ?? 'NONE';
    final interpretation = dp['interpretation'] ?? '';
    final delta = (dp['delta'] ?? 0.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.wb_twilight, size: 18, color: AppColors.accentCoral),
            const SizedBox(width: 8),
            Text('Dawn Phenomenon', style: GoogleFonts.outfit(
              fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: flag == 'NONE' ? AppColors.accentGreenLight : AppColors.highBg,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(flag, style: GoogleFonts.outfit(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: flag == 'NONE' ? AppColors.accentGreen : AppColors.accentWarning)),
            ),
          ]),
          const SizedBox(height: 10),
          Text('+${delta.toStringAsFixed(1)} mg/dL rise (2AM → 7AM)',
            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary)),
          if (interpretation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(interpretation, style: GoogleFonts.outfit(
              fontSize: 12, color: AppColors.textTertiary, height: 1.4)),
          ],
        ],
      ),
    );
  }
}
