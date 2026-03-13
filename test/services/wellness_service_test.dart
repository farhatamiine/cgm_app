import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cgm_app/services/wellness_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Reset SharedPreferences and service state before each test
    SharedPreferences.setMockInitialValues({});
    WellnessService.resetForTesting();
  });

  group('WellnessService — water defaults', () {
    test('waterGoal defaults to 8', () async {
      await WellnessService().init();
      expect(WellnessService().waterGoal, 8);
    });

    test('waterCount defaults to 0', () async {
      await WellnessService().init();
      expect(WellnessService().waterCount, 0);
    });

    test('waterReminderEnabled defaults to true', () async {
      await WellnessService().init();
      expect(WellnessService().waterReminderEnabled, isTrue);
    });

    test('waterIntervalHours defaults to 2', () async {
      await WellnessService().init();
      expect(WellnessService().waterIntervalHours, 2);
    });

    test('waterGoalReached is false when count is 0', () async {
      await WellnessService().init();
      expect(WellnessService().waterGoalReached, isFalse);
    });
  });

  group('WellnessService — addGlass', () {
    test('increments waterCount by 1', () async {
      await WellnessService().init();
      await WellnessService().addGlass();
      expect(WellnessService().waterCount, 1);
    });

    test('waterGoalReached becomes true when count reaches goal', () async {
      SharedPreferences.setMockInitialValues({'wellness_water_goal': 2});
      await WellnessService().init();
      await WellnessService().addGlass();
      await WellnessService().addGlass();
      expect(WellnessService().waterGoalReached, isTrue);
    });

    test('count is capped at goal * 2', () async {
      SharedPreferences.setMockInitialValues({'wellness_water_goal': 2});
      await WellnessService().init();
      for (int i = 0; i < 10; i++) {
        await WellnessService().addGlass();
      }
      expect(WellnessService().waterCount, 4); // 2 * 2
    });
  });

  group('WellnessService — saveWaterSettings', () {
    test('saves goal correctly', () async {
      await WellnessService().init();
      await WellnessService().saveWaterSettings(
        goal: 10, enabled: true, intervalHours: 2, startHour: 8, endHour: 22,
      );
      expect(WellnessService().waterGoal, 10);
    });

    test('ignores invalid intervalHours', () async {
      await WellnessService().init();
      await WellnessService().saveWaterSettings(
        goal: 8, enabled: true, intervalHours: 5, startHour: 8, endHour: 22,
      );
      expect(WellnessService().waterIntervalHours, 2); // unchanged default
    });

    test('ignores endHour <= startHour', () async {
      await WellnessService().init();
      await WellnessService().saveWaterSettings(
        goal: 8, enabled: true, intervalHours: 2, startHour: 22, endHour: 8,
      );
      expect(WellnessService().waterStartHour, 8); // unchanged
    });
  });
}
