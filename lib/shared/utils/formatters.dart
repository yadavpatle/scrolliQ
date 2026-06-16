/// Format helpers used across the UI.
class Formatters {
  Formatters._();

  /// Formats minutes as `Xh Ym`.
  static String minutes(int minutes) {
    if (minutes <= 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  /// Greeting based on local time.
  static String greeting([DateTime? now]) {
    final t = (now ?? DateTime.now()).hour;
    if (t < 12) return 'Good morning';
    if (t < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// First name from a full name.
  static String firstName(String? full) {
    if (full == null || full.trim().isEmpty) return 'there';
    return full.trim().split(' ').first;
  }
}
