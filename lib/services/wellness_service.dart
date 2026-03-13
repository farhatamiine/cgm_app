import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/vitamin_reminder.dart';
import 'notification_plugin.dart';

/// Manages daily water intake tracking and per-vitamin reminder notifications.
/// Persists all state in SharedPreferences. Extends [ChangeNotifier] so the
/// [WellnessScreen] can use [ListenableBuilder] for reactive rebuilds.
class WellnessService extends ChangeNotifier {
  static WellnessService _instance = WellnessService._();
  factory WellnessService() => _instance;
  WellnessService._();

  /// Testing only — resets the singleton so tests start clean.
  @visibleForTesting
  static void resetForTesting() {
    _instance = WellnessService._();
  }

  SharedPreferences? _prefs;

  // ── Internal state ────────────────────────────────────────────────────────

  int _waterGoal = 8;
  int _waterCount = 0;
  bool _waterEnabled = true;
  int _waterInterval = 2;
  int _waterStart = 8;
  int _waterEnd = 22;
  List<VitaminReminder> _vitamins = [];

  // Debounce timer for persistence after addGlass()
  Timer? _saveDebounce;

  // ── Public getters ────────────────────────────────────────────────────────

  int get waterGoal => _waterGoal;
  int get waterCount => _waterCount;
  bool get waterReminderEnabled => _waterEnabled;
  int get waterIntervalHours => _waterInterval;
  int get waterStartHour => _waterStart;
  int get waterEndHour => _waterEnd;
  bool get waterGoalReached => _waterCount >= _waterGoal;

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadWaterState();
    _loadVitamins();
    await _createAndroidChannel();
    await _scheduleAllNotifications();
    notifyListeners();
  }

  void _loadWaterState() {
    _waterGoal = _prefs!.getInt('wellness_water_goal') ?? 8;
    _waterEnabled = _prefs!.getBool('wellness_water_reminder_enabled') ?? true;
    _waterInterval = _prefs!.getInt('wellness_water_interval_hours') ?? 2;
    _waterStart = _prefs!.getInt('wellness_water_start_hour') ?? 8;
    _waterEnd = _prefs!.getInt('wellness_water_end_hour') ?? 22;

    final today = _todayKey();
    _waterCount = _prefs!.getInt('wellness_water_count_$today') ?? 0;
  }

  void _loadVitamins() {
    final raw = _prefs!.getString('wellness_vitamins') ?? '[]';
    try {
      final list = json.decode(raw) as List<dynamic>;
      _vitamins = list
          .whereType<Map<String, dynamic>>()
          .map(VitaminReminder.fromJson)
          .toList();
    } catch (_) {
      _vitamins = [];
    }
  }

  // ── Water ─────────────────────────────────────────────────────────────────

  /// Increments the water count. UI updates immediately via [notifyListeners].
  /// If [waterGoalReached], notification cancellation happens immediately.
  /// SharedPreferences write + notification reschedule are debounced 500ms.
  Future<void> addGlass() async {
    if (_waterCount >= _waterGoal * 2) return;
    _waterCount++;
    notifyListeners();

    // Immediate: cancel water reminders the moment goal is reached
    if (waterGoalReached) {
      await _cancelWaterNotifications();
    }

    // Debounced: persist count + reschedule if not goal-reached
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () async {
      await _prefs?.setInt(
          'wellness_water_count_${_todayKey()}', _waterCount);
      if (!waterGoalReached) {
        await _scheduleWaterNotifications();
      }
    });
  }

  /// Saves water settings. Validates inputs; ignores invalid values.
  /// Always cancels and reschedules water notifications.
  Future<void> saveWaterSettings({
    required int goal,
    required bool enabled,
    required int intervalHours,
    required int startHour,
    required int endHour,
  }) async {
    // Validate
    if (![1, 2, 3, 4].contains(intervalHours)) return;
    if (endHour <= startHour) return;

    _waterGoal = goal.clamp(1, 20);
    _waterEnabled = enabled;
    _waterInterval = intervalHours;
    _waterStart = startHour;
    _waterEnd = endHour;

    await _prefs?.setInt('wellness_water_goal', _waterGoal);
    await _prefs?.setBool('wellness_water_reminder_enabled', _waterEnabled);
    await _prefs?.setInt('wellness_water_interval_hours', _waterInterval);
    await _prefs?.setInt('wellness_water_start_hour', _waterStart);
    await _prefs?.setInt('wellness_water_end_hour', _waterEnd);

    await _cancelWaterNotifications();
    if (_waterEnabled) await _scheduleWaterNotifications();

    notifyListeners();
  }

  // ── Vitamins ──────────────────────────────────────────────────────────────

  /// Returns vitamins with [takenToday] computed live from SharedPreferences.
  List<({VitaminReminder vitamin, bool takenToday})> get vitaminsWithStatus {
    final today = _todayKey();
    return _vitamins.map((v) {
      final taken =
          _prefs?.getBool('wellness_taken_${v.id}_$today') ?? false;
      return (vitamin: v, takenToday: taken);
    }).toList();
  }

  /// Adds a vitamin. Returns false (no-op) if already at 10 vitamins.
  Future<bool> addVitamin(String name, int hour, int minute) async {
    if (_vitamins.length >= 10) return false;

    final v = VitaminReminder(
      id: VitaminReminder.uniqueId(),
      name: name.trim(),
      hour: hour,
      minute: minute,
    );
    _vitamins.add(v);
    await _persistVitamins();
    await _scheduleVitaminNotification(v, _vitamins.length - 1);
    notifyListeners();
    return true;
  }

  /// Deletes a vitamin, cancels all vitamin notifications, re-indexes and
  /// reschedules remaining vitamins so ID = 300 + list position.
  Future<void> deleteVitamin(String id) async {
    _vitamins.removeWhere((v) => v.id == id);
    await _persistVitamins();
    await _cancelAllVitaminNotifications();
    for (int i = 0; i < _vitamins.length; i++) {
      await _scheduleVitaminNotification(_vitamins[i], i);
    }
    notifyListeners();
  }

  /// Marks a vitamin as taken (or untaken) for today.
  Future<void> markTaken(String id, bool taken) async {
    await _prefs?.setBool(
        'wellness_taken_${id}_${_todayKey()}', taken);
    notifyListeners();
  }

  // ── Persistence helpers ───────────────────────────────────────────────────

  Future<void> _persistVitamins() async {
    final encoded =
        json.encode(_vitamins.map((v) => v.toJson()).toList());
    await _prefs?.setString('wellness_vitamins', encoded);
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  // ── Notification scheduling ───────────────────────────────────────────────

  Future<void> _createAndroidChannel() async {
    try {
      await notificationPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            'wellness_reminders',
            'Wellness Reminders',
            description: 'Daily water and vitamin reminders',
            importance: Importance.defaultImportance,
          ));
    } catch (e) {
      debugPrint('[Wellness] Failed to create Android channel: $e');
    }
  }

  Future<void> _scheduleAllNotifications() async {
    if (_waterEnabled) await _scheduleWaterNotifications();
    for (int i = 0; i < _vitamins.length; i++) {
      await _scheduleVitaminNotification(_vitamins[i], i);
    }
  }

  Future<void> _scheduleWaterNotifications() async {
    await _cancelWaterNotifications();
    if (!_waterEnabled) return;

    int slotIndex = 0;
    for (int h = _waterStart; h < _waterEnd; h += _waterInterval) {
      if (slotIndex > 22) break; // IDs 200-222 max 23 slots
      await _scheduleDaily(
        id: 200 + slotIndex,
        hour: h,
        minute: 0,
        title: '💧 Drink some water!',
        body: "Don't forget your daily water goal.",
      );
      slotIndex++;
    }
  }

  Future<void> _cancelWaterNotifications() async {
    for (int i = 0; i <= 22; i++) {
      try {
        await notificationPlugin.cancel(200 + i);
      } catch (_) {}
    }
  }

  Future<void> _scheduleVitaminNotification(
      VitaminReminder v, int index) async {
    await _scheduleDaily(
      id: 300 + index,
      hour: v.hour,
      minute: v.minute,
      title: '💊 Vitamin reminder',
      body: 'Time to take your ${v.name}.',
    );
  }

  Future<void> _cancelAllVitaminNotifications() async {
    for (int i = 0; i < 10; i++) {
      try {
        await notificationPlugin.cancel(300 + i);
      } catch (_) {}
    }
  }

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    try {
      final location = tz.local;
      final now = tz.TZDateTime.now(location);
      var scheduled = tz.TZDateTime(location, now.year, now.month, now.day, hour, minute);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await notificationPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'wellness_reminders',
            'Wellness Reminders',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('[Wellness] Failed to schedule notification $id: $e');
    }
  }
}
