import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/enums.dart';
import '../../domain/entities/request_entity.dart';
import '../../domain/repositories/request_repository.dart';
import '../../../drivers/domain/entities/driver_entity.dart';
import '../models/request_model.dart';

class RequestRepositoryImpl implements RequestRepository {
  final FirebaseFirestore _db;

  RequestRepositoryImpl({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  @override
  Stream<List<RequestEntity>> watchAll() {
    return _db.collection('requests').snapshots().map(
      (snap) => snap.docs.map((doc) => RequestModel.fromFirestore(doc)).toList(),
    );
  }

  @override
  Stream<List<RequestEntity>> watchByDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _db
        .collection('requests')
        .where('requestedDateTime', isGreaterThanOrEqualTo: startOfDay)
        .where('requestedDateTime', isLessThan: endOfDay)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => RequestModel.fromFirestore(doc)).toList());
  }

  @override
  Future<void> updateStatus(String requestId, RequestStatus status) {
    return _db.collection('requests').doc(requestId).update({
      'status': status.name,
      'statusChangedDateTime': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> assignDriver(String requestId, DriverEntity driver) {
    return _db.collection('requests').doc(requestId).update({
      'assignedDriverId': driver.id,
      'assignedDriverName': driver.name,
      'assignedDriverMobile': driver.mobile,
      'assignedAt': FieldValue.serverTimestamp(),
      'status': RequestStatus.assigned.name,
    });
  }
}
