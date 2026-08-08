import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/registration_request_entity.dart';
import '../../domain/repositories/registration_request_repository.dart';
import '../models/registration_request_model.dart';
import '../../../drivers/domain/entities/driver_entity.dart';
import '../../../drivers/domain/repositories/driver_repository.dart';

class RegistrationRequestRepositoryImpl implements RegistrationRequestRepository {
  final FirebaseFirestore _db;
  final DriverRepository _driverRepository;

  RegistrationRequestRepositoryImpl({
    required DriverRepository driverRepository,
    FirebaseFirestore? db,
  })  : _driverRepository = driverRepository,
        _db = db ?? FirebaseFirestore.instance;

  @override
  Stream<List<RegistrationRequestEntity>> watchPending() {
    return _db
        .collection('registration_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => RegistrationRequestModel.fromFirestore(doc)).toList());
  }

  @override
  Future<void> approve(RegistrationRequestEntity request) async {
    if (request.type == RegistrationType.driver) {
      await _driverRepository.addDriver(DriverEntity(
        id: '',
        nic: request.nic,
        name: request.name,
        mobile: request.mobile,
        email: request.email,
        age: 0,
        lastLicenseRenewed: DateTime.now(),
        workStartedDate: DateTime.now(),
      ));
    }
    await _db.collection('registration_requests').doc(request.id).update({
      'status': 'approved',
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> reject(RegistrationRequestEntity request) {
    return _db.collection('registration_requests').doc(request.id).update({
      'status': 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }
}
