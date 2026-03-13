/// Represents a single vitamin/supplement with a daily reminder time.
/// [takenToday] is NOT stored here — it is computed at read time from
/// SharedPreferences key `wellness_taken_<id>_YYYY-MM-DD`.
class VitaminReminder {
  final String id;
  final String name;
  final int hour;
  final int minute;

  const VitaminReminder({
    required this.id,
    required this.name,
    required this.hour,
    required this.minute,
  });

  // ── Unique ID generation ──────────────────────────────────────────────────

  static int _counter = 0;

  /// Generates a collision-resistant id: "vit_<epochMs>_<counter>".
  /// The static counter guarantees uniqueness even within the same millisecond.
  static String uniqueId() {
    _counter++;
    return 'vit_${DateTime.now().millisecondsSinceEpoch}_$_counter';
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'hour': hour,
        'minute': minute,
      };

  factory VitaminReminder.fromJson(Map<String, dynamic> json) =>
      VitaminReminder(
        id: json['id'] as String,
        name: json['name'] as String,
        hour: json['hour'] as int,
        minute: json['minute'] as int,
      );
}
