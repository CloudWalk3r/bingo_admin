import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/driver_entity.dart';

class DriverModel extends DriverEntity {
  DriverModel({
    required super.id,
    required super.nic,
    required super.name,
    required super.mobile,
    required super.email,
    required super.age,
    required super.lastLicenseRenewed,
    required super.workStartedDate,
  });

  factory DriverModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DriverModel(
      id: doc.id,
      nic: data['nic'] ?? '',
      name: data['name'] ?? '',
      mobile: data['mobile'] ?? '',
      email: data['email'] ?? '',
      age: (data['age'] as num?)?.toInt() ?? 0,
      lastLicenseRenewed: data['lastLicenseRenewed'] != null
          ? (data['lastLicenseRenewed'] as Timestamp).toDate()
          : DateTime.now(),
      workStartedDate: data['workStartedDate'] != null
          ? (data['workStartedDate'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nic': nic,
      'name': name,
      'mobile': mobile,
      'email': email.trim().toLowerCase(),
      'age': age,
      'lastLicenseRenewed': Timestamp.fromDate(lastLicenseRenewed),
      'workStartedDate': Timestamp.fromDate(workStartedDate),
    };
  }
}
