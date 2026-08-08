import '../../domain/entities/driver_location_entity.dart';

class DriverLocationModel extends DriverLocationEntity {
  const DriverLocationModel({
    required super.safeEmail,
    required super.driverEmail,
    required super.driverName,
    required super.latitude,
    required super.longitude,
    required super.accuracy,
    required super.heading,
    required super.speed,
    required super.status,
    required super.updatedAt,
    required super.startedAt,
  });

  /// Builds from a child snapshot at `Driver_Live_Location/{safeEmail}`.
  static DriverLocationModel? fromRtdb(String key, Object? raw) {
    if (raw is! Map) return null;
    final data = Map<String, dynamic>.from(
      raw.map((k, v) => MapEntry(k.toString(), v)),
    );

    final lat = _parseDouble(data['Lat']);
    final lng = _parseDouble(data['Lng']);
    if (lat == null || lng == null) return null;

    return DriverLocationModel(
      safeEmail: key,
      driverEmail: (data['Driver_Email'] ?? key).toString(),
      driverName: (data['Driver_Name'] ?? 'Unknown Driver').toString(),
      latitude: lat,
      longitude: lng,
      accuracy: _parseDouble(data['Accuracy']) ?? 0,
      heading: _parseDouble(data['Heading']) ?? 0,
      speed: _parseDouble(data['Speed']) ?? 0,
      status: (data['Status'] ?? 'Unknown').toString(),
      updatedAt: _parseDate(data['Updated_At']),
      startedAt: _parseDate(data['Started_At']),
    );
  }
}

double? _parseDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

DateTime? _parseDate(Object? v) {
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
  return null;
}
