import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/driver_entity.dart';
import '../../domain/repositories/driver_repository.dart';
import '../models/driver_model.dart';

class DriverRepositoryImpl implements DriverRepository {
  final FirebaseFirestore _db;

  DriverRepositoryImpl({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  @override
  Stream<List<DriverEntity>> watchAll() {
    return _db.collection('drivers').snapshots().map(
      (snap) => snap.docs.map((doc) => DriverModel.fromFirestore(doc)).toList(),
    );
  }

  @override
  Future<void> addDriver(DriverEntity driver) {
    final model = DriverModel(
      id: '',
      nic: driver.nic,
      name: driver.name,
      mobile: driver.mobile,
      email: driver.email,
      age: driver.age,
      lastLicenseRenewed: driver.lastLicenseRenewed,
      workStartedDate: driver.workStartedDate,
    );
    return _db.collection('drivers').add(model.toFirestore());
  }
}
