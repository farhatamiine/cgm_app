import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/colors.dart';
import '../core/theme.dart';
import '../models/vitamin_reminder.dart';
import '../services/wellness_service.dart';

class WellnessScreen extends StatelessWidget {
  const WellnessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WellnessService(),
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 24),
                _buildSectionTitle('Water'),
                const SizedBox(height: 12),
                _buildWaterCard(context),
                const SizedBox(height: 28),
                _buildSectionTitle('Vitamins'),
                const SizedBox(height: 12),
                _buildVitaminSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back_ios_rounded,
              size: 20, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Wellness',
              style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          Text("Today's health habits",
              style: GoogleFonts.outfit(
                  fontSize: 14, color: AppColors.textSecondary)),
        ]),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary));
  }

  // ── Water ──────────────────────────────────────────────────────────────────

  Widget _buildWaterCard(BuildContext context) {
    final svc = WellnessService();
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        _WaterProgressRing(count: svc.waterCount, goal: svc.waterGoal),
        const SizedBox(height: 16),
        _buildAddGlassButton(svc),
        const SizedBox(height: 16),
        _buildGlassIcons(svc),
        const SizedBox(height: 20),
        const Divider(color: AppColors.borderSubtle, height: 1),
        const SizedBox(height: 16),
        _buildWaterSettings(context, svc),
      ]),
    );
  }

  Widget _buildAddGlassButton(WellnessService svc) {
    final atCap = svc.waterCount >= svc.waterGoal * 2;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: atCap ? null : () => WellnessService().addGlass(),
        icon: Icon(
          svc.waterGoalReached
              ? Icons.check_circle_outline_rounded
              : Icons.add_rounded,
          size: 18,
        ),
        label: Text(
          svc.waterGoalReached ? 'Goal reached!' : 'Add a glass',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accentGreen,
          disabledBackgroundColor: AppColors.accentGreen.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildGlassIcons(WellnessService svc) {
    final filled = svc.waterCount.clamp(0, svc.waterGoal);
    final empty = (svc.waterGoal - filled).clamp(0, svc.waterGoal);
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (int i = 0; i < filled; i++)
          const Icon(Icons.water_drop_rounded,
              size: 20, color: AppColors.accentGreen),
        for (int i = 0; i < empty; i++)
          Icon(Icons.water_drop_outlined,
              size: 20, color: AppColors.textDisabled),
      ],
    );
  }

  Widget _buildWaterSettings(BuildContext context, WellnessService svc) {
    return Column(children: [
      // Goal stepper
      _SettingsRow(
        label: 'Daily goal',
        child: Row(children: [
          _StepperButton(
            icon: Icons.remove,
            onTap: svc.waterGoal > 1
                ? () => WellnessService().saveWaterSettings(
                      goal: svc.waterGoal - 1,
                      enabled: svc.waterReminderEnabled,
                      intervalHours: svc.waterIntervalHours,
                      startHour: svc.waterStartHour,
                      endHour: svc.waterEndHour,
                    )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('${svc.waterGoal}',
                style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ),
          _StepperButton(
            icon: Icons.add,
            onTap: svc.waterGoal < 20
                ? () => WellnessService().saveWaterSettings(
                      goal: svc.waterGoal + 1,
                      enabled: svc.waterReminderEnabled,
                      intervalHours: svc.waterIntervalHours,
                      startHour: svc.waterStartHour,
                      endHour: svc.waterEndHour,
                    )
                : null,
          ),
        ]),
      ),
      const SizedBox(height: 12),
      // Interval dropdown
      _SettingsRow(
        label: 'Remind every',
        child: DropdownButton<int>(
          value: svc.waterIntervalHours,
          underline: const SizedBox(),
          style: GoogleFonts.outfit(
              fontSize: 14, color: AppColors.textPrimary),
          items: const [
            DropdownMenuItem(value: 1, child: Text('1 hour')),
            DropdownMenuItem(value: 2, child: Text('2 hours')),
            DropdownMenuItem(value: 3, child: Text('3 hours')),
            DropdownMenuItem(value: 4, child: Text('4 hours')),
          ],
          onChanged: (v) {
            if (v == null) return;
            WellnessService().saveWaterSettings(
              goal: svc.waterGoal,
              enabled: svc.waterReminderEnabled,
              intervalHours: v,
              startHour: svc.waterStartHour,
              endHour: svc.waterEndHour,
            );
          },
        ),
      ),
      const SizedBox(height: 12),
      // Active hours
      _SettingsRow(
        label: 'Active hours',
        child: Row(children: [
          _TimeChip(
            hour: svc.waterStartHour,
            minute: 0,
            onPick: (tod) => WellnessService().saveWaterSettings(
              goal: svc.waterGoal,
              enabled: svc.waterReminderEnabled,
              intervalHours: svc.waterIntervalHours,
              startHour: tod.hour,
              endHour: svc.waterEndHour,
            ),
            context: context,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('→',
                style: GoogleFonts.outfit(color: AppColors.textTertiary)),
          ),
          _TimeChip(
            hour: svc.waterEndHour,
            minute: 0,
            onPick: (tod) => WellnessService().saveWaterSettings(
              goal: svc.waterGoal,
              enabled: svc.waterReminderEnabled,
              intervalHours: svc.waterIntervalHours,
              startHour: svc.waterStartHour,
              endHour: tod.hour,
            ),
            context: context,
          ),
        ]),
      ),
      const SizedBox(height: 12),
      // Reminders toggle
      _SettingsRow(
        label: 'Reminders',
        child: Switch(
          value: svc.waterReminderEnabled,
          activeThumbColor: AppColors.accentGreen,
          onChanged: (v) => WellnessService().saveWaterSettings(
            goal: svc.waterGoal,
            enabled: v,
            intervalHours: svc.waterIntervalHours,
            startHour: svc.waterStartHour,
            endHour: svc.waterEndHour,
          ),
        ),
      ),
    ]);
  }

  // ── Vitamins ───────────────────────────────────────────────────────────────

  Widget _buildVitaminSection(BuildContext context) {
    final svc = WellnessService();
    final vitamins = svc.vitaminsWithStatus;

    return Column(children: [
      ...vitamins.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _VitaminCard(
              vitamin: entry.vitamin,
              takenToday: entry.takenToday,
            ),
          )),
      const SizedBox(height: 4),
      SizedBox(
        width: double.infinity,
        child: Tooltip(
          message: vitamins.length >= 10 ? 'Maximum 10 vitamins reached' : '',
          child: FilledButton.icon(
            onPressed: vitamins.length >= 10
                ? null
                : () => _showAddVitaminSheet(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('Add vitamin',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentCoral,
              disabledBackgroundColor:
                  AppColors.accentCoral.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
    ]);
  }

  void _showAddVitaminSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _AddVitaminSheet(),
    );
  }
}

// ── Water progress ring ────────────────────────────────────────────────────────

class _WaterProgressRing extends StatelessWidget {
  final int count;
  final int goal;

  const _WaterProgressRing({required this.count, required this.goal});

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? (count / goal).clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(
          size: const Size(120, 120),
          painter: _RingPainter(progress: progress),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$count',
              style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          Text('/ $goal',
              style: GoogleFonts.outfit(
                  fontSize: 13, color: AppColors.textSecondary)),
        ]),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 10.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = AppColors.borderSubtle
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Progress
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = AppColors.accentGreen
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ── Vitamin card ────────────────────────────────────────────────────────────────

class _VitaminCard extends StatelessWidget {
  final VitaminReminder vitamin;
  final bool takenToday;

  const _VitaminCard({required this.vitamin, required this.takenToday});

  @override
  Widget build(BuildContext context) {
    final timeStr = TimeOfDay(hour: vitamin.hour, minute: vitamin.minute)
        .format(context);
    return GestureDetector(
      onLongPress: () => _confirmDelete(context),
      child: Container(
        decoration: AppTheme.cardDecoration,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accentCoral.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.medication_outlined,
                color: AppColors.accentCoral, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(vitamin.name,
                style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            Text(timeStr,
                style: GoogleFonts.outfit(
                    fontSize: 13, color: AppColors.textTertiary)),
          ])),
          takenToday
              ? FilledButton(
                  onPressed: () =>
                      WellnessService().markTaken(vitamin.id, false),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentGreen,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  child: Text('✓ Taken',
                      style: GoogleFonts.outfit(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                )
              : OutlinedButton(
                  onPressed: () =>
                      WellnessService().markTaken(vitamin.id, true),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.accentCoral),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  child: Text('Take',
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentCoral)),
                ),
        ]),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete vitamin?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        content: Text(
          "This will remove '${vitamin.name}' and cancel its daily reminder.",
          style: GoogleFonts.outfit(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit()),
          ),
          FilledButton(
            onPressed: () {
              WellnessService().deleteVitamin(vitamin.id);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentRed),
            child: Text('Delete', style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );
  }
}

// ── Add vitamin bottom sheet ────────────────────────────────────────────────────

class _AddVitaminSheet extends StatefulWidget {
  const _AddVitaminSheet();

  @override
  State<_AddVitaminSheet> createState() => _AddVitaminSheetState();
}

class _AddVitaminSheetState extends State<_AddVitaminSheet> {
  final _nameController = TextEditingController();
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _nameController.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Add vitamin',
            style: GoogleFonts.outfit(
                fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        TextField(
          controller: _nameController,
          maxLength: 30,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Vitamin name',
            labelStyle: GoogleFonts.outfit(),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          style: GoogleFonts.outfit(),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            final picked = await showTimePicker(
                context: context, initialTime: _time);
            if (picked != null) setState(() => _time = picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderSubtle),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.alarm_rounded,
                  color: AppColors.textTertiary, size: 20),
              const SizedBox(width: 12),
              Text('Reminder time: ${_time.format(context)}',
                  style: GoogleFonts.outfit(
                      fontSize: 14, color: AppColors.textPrimary)),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: canSave ? _save : null,
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentCoral,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: Text('Save',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    await WellnessService().addVitamin(
      _nameController.text.trim(),
      _time.hour,
      _time.minute,
    );
    if (mounted) Navigator.pop(context);
  }
}

// ── Shared small widgets ────────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _SettingsRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.outfit(
                fontSize: 14, color: AppColors.textSecondary)),
        child,
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: onTap != null
              ? AppColors.accentGreen.withValues(alpha: 0.12)
              : AppColors.borderSubtle,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 16,
            color: onTap != null
                ? AppColors.accentGreen
                : AppColors.textDisabled),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final int hour;
  final int minute;
  final void Function(TimeOfDay) onPick;
  final BuildContext context;

  const _TimeChip({
    required this.hour,
    required this.minute,
    required this.onPick,
    required this.context,
  });

  @override
  Widget build(BuildContext ctx) {
    final display =
        TimeOfDay(hour: hour, minute: minute).format(context);
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(hour: hour, minute: minute));
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.accentGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(display,
            style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.accentGreen)),
      ),
    );
  }
}
