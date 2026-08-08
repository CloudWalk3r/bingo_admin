import '../entities/driver_location_entity.dart';

abstract class DriverLocationRepository {
  /// Emits the live set of drivers currently publishing their location.
  Stream<List<DriverLocationEntity>> watchAll();
}
