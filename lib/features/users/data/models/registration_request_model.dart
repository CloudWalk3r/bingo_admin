import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/registration_request_entity.dart';

class RegistrationRequestModel extends RegistrationRequestEntity {
  RegistrationRequestModel({
    required super.id,
    required super.type,
    required super.status,
    required super.name,
    required super.mobile,
    required super.nic,
    required super.email,
    super.address,
    super.houseNumber,
    required super.submittedAt,
  });

  factory RegistrationRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RegistrationRequestModel(
      id: doc.id,
      type: data['type'] == 'driver' ? RegistrationType.driver : RegistrationType.houseOwner,
      status: switch (data['status']) {
        'approved' => RegistrationStatus.approved,
        'rejected' => RegistrationStatus.rejected,
        _ => RegistrationStatus.pending,
      },
      name: data['name'] ?? '',
      mobile: data['mobile'] ?? '',
      nic: data['nic'] ?? '',
      email: data['email'] ?? '',
      address: data['address'],
      houseNumber: data['houseNumber'],
      submittedAt: data['submittedAt'] != null ? (data['submittedAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }
}
