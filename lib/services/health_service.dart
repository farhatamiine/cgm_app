import 'package:health/health.dart';

/// Summary of today's health data from Health Connect.
class HealthSummary {
  final int steps;
  final int caloriesKcal;
  final double sleepHours;
  final int activeMinutes;
  final List<FitActivity> activities;

  const HealthSummary({
    required this.steps,
    required this.caloriesKcal,
    required this.sleepHours,
    required this.activeMinutes,
    required this.activities,
  });

  static HealthSummary get empty => const HealthSummary(
        steps: 0,
        caloriesKcal: 0,
        sleepHours: 0,
        activeMinutes: 0,
        activities: [],
      );
}

class FitActivity {
  final String type;
  final int durationMinutes;
  final int caloriesKcal;
  final String timeLabel;

  const FitActivity({
    required this.type,
    required this.durationMinutes,
    required this.caloriesKcal,
    required this.timeLabel,
  });
}

enum HcAvailability { available, notInstalled, needsUpdate }

class HealthService {
  static final HealthService _instance = HealthService._();
  factory HealthService() => _instance;
  HealthService._();

  final _health = Health();
  bool _authorized = false;

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.WORKOUT,
    HealthDataType.BLOOD_GLUCOSE,
  ];

  static const _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  bool get isAuthorized => _authorized;

  /// Check if Health Connect is installed and up to date.
  Future<HcAvailability> checkAvailability() async {
    try {
      await _health.configure();
      final status = await _health.getHealthConnectSdkStatus();
      switch (status) {
        case HealthConnectSdkStatus.sdkAvailable:
          return HcAvailability.available;
        case HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired:
          return HcAvailability.needsUpdate;
        default:
          return HcAvailability.notInstalled;
      }
    } catch (_) {
      return HcAvailability.notInstalled;
    }
  }

  /// Opens the Play Store page to install or update Health Connect.
  Future<void> openInstallPage() async {
    try {
      await _health.installHealthConnect();
    } catch (_) {}
  }

  /// Request Health Connect permissions. Returns true if granted.
  Future<bool> requestPermissions() async {
    try {
      await _health.configure();
      _authorized = await _health.requestAuthorization(
        _types,
        permissions: _permissions,
      );
      return _authorized;
    } catch (_) {
      _authorized = false;
      return false;
    }
  }

  /// Check if permissions are already granted without prompting.
  Future<bool> checkPermissions() async {
    try {
      await _health.configure();
      _authorized =
          await _health.hasPermissions(_types, permissions: _permissions) ??
              false;
      return _authorized;
    } catch (_) {
      return false;
    }
  }

  /// Fetch today's steps, calories, sleep (last night), and workouts.
  Future<HealthSummary> getTodaySummary() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // Steps
    int steps = 0;
    try {
      steps = await _health.getTotalStepsInInterval(todayStart, now) ?? 0;
    } catch (_) {}

    // Active calories burned today
    int calories = 0;
    try {
      final calData = await _health.getHealthDataFromTypes(
        startTime: todayStart,
        endTime: now,
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      );
      for (final p in calData) {
        if (p.value is NumericHealthValue) {
          calories +=
              (p.value as NumericHealthValue).numericValue.toInt();
        }
      }
    } catch (_) {}

    // Sleep last night: 6 PM yesterday → noon today
    double sleepHours = 0;
    try {
      final sleepStart = todayStart.subtract(const Duration(hours: 6));
      final sleepEnd = DateTime(now.year, now.month, now.day, 12);
      final sleepData = await _health.getHealthDataFromTypes(
        startTime: sleepStart,
        endTime: sleepEnd,
        types: [HealthDataType.SLEEP_ASLEEP],
      );
      int totalMins = 0;
      for (final p in sleepData) {
        totalMins += p.dateTo.difference(p.dateFrom).inMinutes;
      }
      sleepHours = totalMins / 60.0;
    } catch (_) {}

    // Workouts today → active minutes + activity list
    int activeMinutes = 0;
    final activities = <FitActivity>[];
    try {
      final workoutData = await _health.getHealthDataFromTypes(
        startTime: todayStart,
        endTime: now,
        types: [HealthDataType.WORKOUT],
      );
      for (final p in workoutData) {
        final dur = p.dateTo.difference(p.dateFrom).inMinutes;
        activeMinutes += dur;
        if (p.value is WorkoutHealthValue) {
          final wv = p.value as WorkoutHealthValue;
          activities.add(FitActivity(
            type: _workoutName(wv.workoutActivityType),
            durationMinutes: dur,
            caloriesKcal: wv.totalEnergyBurned?.toInt() ?? 0,
            timeLabel: _fmtTime(p.dateFrom),
          ));
        }
      }
    } catch (_) {}

    return HealthSummary(
      steps: steps,
      caloriesKcal: calories,
      sleepHours: sleepHours,
      activeMinutes: activeMinutes,
      activities: activities,
    );
  }

  String _workoutName(HealthWorkoutActivityType type) {
    switch (type) {
      case HealthWorkoutActivityType.WALKING:
        return 'Walking';
      case HealthWorkoutActivityType.RUNNING:
        return 'Running';
      case HealthWorkoutActivityType.BIKING:
      case HealthWorkoutActivityType.BIKING_STATIONARY:
        return 'Cycling';
      case HealthWorkoutActivityType.SWIMMING_OPEN_WATER:
      case HealthWorkoutActivityType.SWIMMING_POOL:
        return 'Swimming';
      case HealthWorkoutActivityType.STRENGTH_TRAINING:
        return 'Gym';
      case HealthWorkoutActivityType.YOGA:
        return 'Yoga';
      case HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING:
        return 'HIIT';
      case HealthWorkoutActivityType.ELLIPTICAL:
        return 'Elliptical';
      case HealthWorkoutActivityType.STAIR_CLIMBING:
        return 'Stair Climbing';
      default:
        return type.name
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) => w.isNotEmpty
                ? w[0].toUpperCase() + w.substring(1).toLowerCase()
                : '')
            .join(' ');
    }
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $suffix';
  }
}
