import 'package:firebase_database/firebase_database.dart';

import '../../domain/entities/driver_location_entity.dart';
import '../../domain/repositories/driver_location_repository.dart';
import '../models/driver_location_model.dart';

/// Listens to `Driver_Live_Location` in Firebase Realtime Database and emits a
/// deserialized list of active driver positions for the admin dashboard.
class DriverLocationRepositoryImpl implements DriverLocationRepository {
  final DatabaseReference _ref;

  DriverLocationRepositoryImpl({DatabaseReference? ref})
      : _ref = ref ??
            FirebaseDatabase.instance.ref().child('Driver_Live_Location');

  @override
  Stream<List<DriverLocationEntity>> watchAll() {
    return _ref.onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return const <DriverLocationEntity>[];
      final entries = <DriverLocationEntity>[];
      value.forEach((k, v) {
        final model = DriverLocationModel.fromRtdb(k.toString(), v);
        if (model != null) entries.add(model);
      });
      entries.sort((a, b) {
        if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
        return a.driverName.toLowerCase().compareTo(b.driverName.toLowerCase());
      });
      return entries;
    });
  }
}
