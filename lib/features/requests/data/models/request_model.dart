import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/enums.dart';
import '../../domain/entities/request_entity.dart';

class RequestModel extends RequestEntity {
  RequestModel({
    required super.id,
    required super.userName,
    required super.userMobile,
    required super.userAddress,
    super.userEmail,
    required super.requestedDateTime,
    required super.garbageType,
    super.weightInKg = 0.0,
    super.status = RequestStatus.pending,
    super.statusChangedDateTime,
    super.assignedDriverId,
    super.assignedDriverName,
    super.assignedDriverMobile,
    super.assignedAt,
    super.pickupLat,
    super.pickupLng,
  });

  factory RequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    GarbageType gType = GarbageType.biodegradable;
    if (data['garbageType'] == 'nonBiodegradable') gType = GarbageType.nonBiodegradable;
    if (data['garbageType'] == 'glass') gType = GarbageType.glass;

    RequestStatus rStatus = RequestStatus.pending;
    if (data['status'] == 'assigned') rStatus = RequestStatus.assigned;
    if (data['status'] == 'collected') rStatus = RequestStatus.collected;
    if (data['status'] == 'rejected') rStatus = RequestStatus.rejected;

    return RequestModel(
      id: doc.id,
      userName: data['userName'] ?? '',
      userMobile: data['userMobile'] ?? '',
      userAddress: data['userAddress'] ?? '',
      userEmail: data['userEmail'],
      requestedDateTime: data['requestedDateTime'] != null
          ? (data['requestedDateTime'] as Timestamp).toDate()
          : DateTime.now(),
      garbageType: gType,
      weightInKg: (data['weightInKg'] as num?)?.toDouble() ?? 0.0,
      status: rStatus,
      statusChangedDateTime: data['statusChangedDateTime'] != null
          ? (data['statusChangedDateTime'] as Timestamp).toDate()
          : null,
      assignedDriverId: data['assignedDriverId'],
      assignedDriverName: data['assignedDriverName'],
      assignedDriverMobile: data['assignedDriverMobile'],
      assignedAt: data['assignedAt'] != null
          ? (data['assignedAt'] as Timestamp).toDate()
          : null,
      pickupLat: (data['pickupLat'] as num?)?.toDouble(),
      pickupLng: (data['pickupLng'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userName': userName,
      'userMobile': userMobile,
      'userAddress': userAddress,
      'userEmail': userEmail,
      'requestedDateTime': Timestamp.fromDate(requestedDateTime),
      'garbageType': garbageType.name,
      'weightInKg': weightInKg,
      'status': status.name,
      'statusChangedDateTime': statusChangedDateTime != null
          ? Timestamp.fromDate(statusChangedDateTime!)
          : null,
      'assignedDriverId': assignedDriverId,
      'assignedDriverName': assignedDriverName,
      'assignedDriverMobile': assignedDriverMobile,
      'assignedAt': assignedAt != null ? Timestamp.fromDate(assignedAt!) : null,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
    };
  }
}
