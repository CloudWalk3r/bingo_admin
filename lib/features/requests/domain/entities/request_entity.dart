import '../../../../core/constants/enums.dart';

class RequestEntity {
  final String id;
  final String userName;
  final String userMobile;
  final String userAddress;
  final String? userEmail;
  final DateTime requestedDateTime;
  final GarbageType garbageType;
  final double weightInKg;
  RequestStatus status;
  DateTime? statusChangedDateTime;
  String? assignedDriverId;
  String? assignedDriverName;
  String? assignedDriverMobile;
  DateTime? assignedAt;
  final double? pickupLat;
  final double? pickupLng;

  RequestEntity({
    required this.id,
    required this.userName,
    required this.userMobile,
    required this.userAddress,
    this.userEmail,
    required this.requestedDateTime,
    required this.garbageType,
    this.weightInKg = 0.0,
    this.status = RequestStatus.pending,
    this.statusChangedDateTime,
    this.assignedDriverId,
    this.assignedDriverName,
    this.assignedDriverMobile,
    this.assignedAt,
    this.pickupLat,
    this.pickupLng,
  });
}
