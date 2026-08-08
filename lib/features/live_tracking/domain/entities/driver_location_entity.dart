class DriverLocationEntity {
  final String safeEmail;
  final String driverEmail;
  final String driverName;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double heading;
  final double speed;
  final String status;
  final DateTime? updatedAt;
  final DateTime? startedAt;

  const DriverLocationEntity({
    required this.safeEmail,
    required this.driverEmail,
    required this.driverName,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.heading,
    required this.speed,
    required this.status,
    required this.updatedAt,
    required this.startedAt,
  });

  bool get isOnline => status.toLowerCase() == 'online';

  Duration? get stalenessFromNow {
    final t = updatedAt;
    if (t == null) return null;
    return DateTime.now().difference(t);
  }

  bool get isStale {
    final staleness = stalenessFromNow;
    return staleness != null && staleness.inSeconds > 60;
  }
}
