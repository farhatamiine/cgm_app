import 'package:flutter_test/flutter_test.dart';
import 'package:cgm_app/models/vitamin_reminder.dart';

void main() {
  group('VitaminReminder', () {
    test('fromJson/toJson round-trips correctly', () {
      final v = VitaminReminder(
        id: 'vit_123_0',
        name: 'Vitamin D',
        hour: 8,
        minute: 30,
      );
      final json = v.toJson();
      final restored = VitaminReminder.fromJson(json);

      expect(restored.id, 'vit_123_0');
      expect(restored.name, 'Vitamin D');
      expect(restored.hour, 8);
      expect(restored.minute, 30);
    });

    test('uniqueId generates different ids for rapid calls', () {
      final id1 = VitaminReminder.uniqueId();
      final id2 = VitaminReminder.uniqueId();
      expect(id1, isNot(equals(id2)));
    });

    test('id starts with vit_', () {
      final id = VitaminReminder.uniqueId();
      expect(id.startsWith('vit_'), isTrue);
    });
  });
}
