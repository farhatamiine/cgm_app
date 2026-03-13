import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../models/glucose_reading.dart';
import '../services/juggluco_service.dart';
import '../services/user_profile_service.dart';
import '../widgets/badge_chip.dart';
import '../widgets/metric_card.dart';
import 'bolus_advisor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _report;
  bool _loading = true;
  String? _error;

  GlucoseReading? _glucoseReading;
  DateTime? _lastUpdate;

  @override
  void initState() {
    super.initState();
    _loadReport();
    // Subscribe to live Juggluco stream
    JugglucoService().stream.listen((reading) {
      if (mounted) {
        setState(() {
          _glucoseReading = reading;
          _lastUpdate = DateTime.now();
        });
      }
    });
    // Also fetch immediately in case stream hasn't emitted yet
    _fetchGlucoseNow();
  }

  Future<void> _fetchGlucoseNow() async {
    final reading = await JugglucoService().fetchCurrent();
    if (reading != null && mounted) {
      setState(() {
        _glucoseReading = reading;
        _lastUpdate = DateTime.now();
      });
    }
  }

  Future<void> _loadReport() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getGlucoseReport(days: '7');
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
        child: RefreshIndicator(
          onRefresh: _loadReport,
          color: AppColors.accentGreen,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Glucose card is ALWAYS visible regardless of API state
                    _buildCurrentGlucose(),
                    const SizedBox(height: 24),
                    // Report data — show inline loading/error instead of full-screen
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: CircularProgressIndicator(color: AppColors.accentGreen),
                        ),
                      )
                    else if (_error != null)
                      _buildReportError()
                    else ...[
                      _buildMetrics(),
                      const SizedBox(height: 24),
                      _buildTirSection(),
                      const SizedBox(height: 24),
                      _buildPatterns(),
                    ],
                    const SizedBox(height: 24),
                    _buildBolusAdvisorCard(),
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
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good morning,';
    } else if (hour < 17) {
      greeting = 'Good afternoon,';
    } else {
      greeting = 'Good evening,';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: GoogleFonts.outfit(
                fontSize: 14, color: AppColors.textSecondary)),
              Text(UserProfileService().name, style: GoogleFonts.outfit(
                fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(
                color: AppColors.shadowColorDark, blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: const Icon(Icons.notifications_outlined,
                size: 20, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentGlucose() {
    final hasReading = _glucoseReading != null;
    final glucoseValue = hasReading ? _glucoseReading!.value.toStringAsFixed(0) : '--';
    final trend = hasReading ? _glucoseReading!.trend : 'stable';

    GlucoseStatus status;
    String statusLabel;
    if (!hasReading) {
      status = GlucoseStatus.inRange;
      statusLabel = 'No Data';
    } else {
      final v = _glucoseReading!.value;
      if (v < 70) {
        status = GlucoseStatus.low;
        statusLabel = 'Low';
      } else if (v <= 180) {
        status = GlucoseStatus.inRange;
        statusLabel = 'In Range';
      } else {
        status = GlucoseStatus.high;
        statusLabel = 'High';
      }
    }

    IconData trendIcon;
    Color trendColor;
    switch (trend) {
      case 'rising':
        trendIcon = Icons.trending_up_rounded;
        trendColor = AppColors.accentWarning;
        break;
      case 'falling':
        trendIcon = Icons.trending_down_rounded;
        trendColor = AppColors.accentRed;
        break;
      default:
        trendIcon = Icons.trending_flat_rounded;
        trendColor = AppColors.accentGreen;
    }

    String updatedText;
    if (_lastUpdate == null) {
      updatedText = 'Waiting for CGM data…';
    } else {
      final mins = DateTime.now().difference(_lastUpdate!).inMinutes;
      updatedText = 'Updated $mins min ago via CGM';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Current Glucose',
                  style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary)),
              const SizedBox(width: 6),
              Icon(trendIcon, size: 16, color: trendColor),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(glucoseValue,
                  style: GoogleFonts.outfit(
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('mg/dL',
                    style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          BadgeChip(label: statusLabel, status: status),
          const SizedBox(height: 8),
          Text(updatedText,
              style: GoogleFonts.outfit(
                  fontSize: 12, color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _buildReportError() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(children: [
        const Icon(Icons.cloud_off_rounded, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: 10),
        Expanded(child: Text('Could not load report data',
            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary))),
        GestureDetector(
          onTap: _loadReport,
          child: Text('Retry',
              style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentGreen)),
        ),
      ]),
    );
  }

  Widget _buildMetrics() {
    final stats = _report?['stats'];
    final avg = stats?['stats']?['average']?.toStringAsFixed(0) ?? '--';
    final gmi = stats?['stats']?['gmi']?.toStringAsFixed(1) ?? '--';
    final variability = _report?['variability'];
    final highest = variability?['highest']?.toStringAsFixed(0) ?? '--';

    return Row(
      children: [
        Expanded(child: MetricCard(label: 'Average', value: avg)),
        const SizedBox(width: 12),
        Expanded(child: MetricCard(label: "Today's High", value: highest)),
        const SizedBox(width: 12),
        Expanded(child: MetricCard(label: 'GMI', value: gmi, unit: '%')),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Time in Range', style: GoogleFonts.outfit(
                fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Text('${tir.toStringAsFixed(0)}%', style: GoogleFonts.outfit(
                fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.accentGreen)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Row(
              children: [
                Flexible(
                  flex: tir.round().clamp(1, 100),
                  child: Container(height: 10, color: AppColors.accentGreen),
                ),
                const SizedBox(width: 2),
                Flexible(
                  flex: tar.round().clamp(1, 100),
                  child: Container(height: 10, color: AppColors.accentWarning),
                ),
                const SizedBox(width: 2),
                Flexible(
                  flex: tbr.round().clamp(1, 100),
                  child: Container(height: 10, color: AppColors.accentRed),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _tirLegend(AppColors.accentGreen, 'In Range ${tir.toStringAsFixed(0)}%'),
              const SizedBox(width: 16),
              _tirLegend(AppColors.accentWarning, 'High ${tar.toStringAsFixed(0)}%'),
              const SizedBox(width: 16),
              _tirLegend(AppColors.accentRed, 'Low ${tbr.toStringAsFixed(0)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tirLegend(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.outfit(
          fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildBolusAdvisorCard() {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const BolusAdvisorScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.accentCoral, Color(0xFFE8A080)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, color: Colors.white, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Smart Bolus Timing', style: GoogleFonts.outfit(
                    fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  Text('Get advice before your next meal', style: GoogleFonts.outfit(
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

  Widget _buildPatterns() {
    final patterns = _report?['patterns'];
    if (patterns == null) return const SizedBox.shrink();

    final periods = [
      ('Morning', patterns['morning']),
      ('Afternoon', patterns['afternoon']),
      ('Evening', patterns['evening']),
      ('Night', patterns['night']),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Daily Patterns', style: GoogleFonts.outfit(
              fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            Text('7 days', style: GoogleFonts.outfit(
              fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.accentCoral)),
          ],
        ),
        const SizedBox(height: 12),
        ...periods.map((p) {
          final name = p.$1;
          final data = p.$2;
          if (data == null) return const SizedBox.shrink();
          final avg = (data['avg'] ?? 0).toString();
          final readings = (data['reading'] ?? 0).toString();
          final time = data['time'] ?? '';
          double avgVal = double.tryParse(avg) ?? 0;
          Color dotColor = avgVal > 180
              ? AppColors.accentWarning
              : avgVal < 70
                  ? AppColors.accentRed
                  : AppColors.accentGreen;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration,
              child: Row(
                children: [
                  Container(width: 10, height: 10,
                    decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$avg mg/dL', style: GoogleFonts.outfit(
                          fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        Text('$name  •  $time  •  $readings readings',
                          style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
