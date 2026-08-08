import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  UserModel({
    required super.id,
    required super.houseNumber,
    required super.ownerName,
    required super.nic,
    required super.mobile,
    super.isPaidManually = false,
    super.lastPaymentUpdateDate,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      houseNumber: data['houseNumber'] ?? data['House_Number'] ?? '',
      ownerName: data['ownerName'] ?? data['Owner_Name'] ?? '',
      nic: data['nic'] ?? data['NIC'] ?? '',
      mobile: data['mobile'] ?? data['Owner_Mobile'] ?? '',
      isPaidManually: data['isPaidManually'] ?? false,
      lastPaymentUpdateDate: data['lastPaymentUpdateDate'] != null
          ? (data['lastPaymentUpdateDate'] as Timestamp).toDate()
          : null,
    );
  }

  /// Builds a user row from the house owner's Realtime Database profile
  /// (the BinGo app's source of truth for registration) plus whatever
  /// admin-only payment metadata exists for them in Firestore, if any.
  factory UserModel.fromRealtimeProfile(String id, Map profileInfo, Map<String, dynamic>? paymentData) {
    return UserModel(
      id: id,
      houseNumber: (profileInfo['Registered_House_ID'] ?? '').toString().replaceAll('_', '/'),
      ownerName: (profileInfo['Owner_Name'] ?? '').toString(),
      nic: (profileInfo['Owner_NIC'] ?? '').toString(),
      mobile: (profileInfo['Owner_Mobile'] ?? '').toString(),
      isPaidManually: paymentData?['isPaidManually'] ?? false,
      lastPaymentUpdateDate: paymentData?['lastPaymentUpdateDate'] != null
          ? (paymentData!['lastPaymentUpdateDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'houseNumber': houseNumber,
      'ownerName': ownerName,
      'nic': nic,
      'mobile': mobile,
      'isPaidManually': isPaidManually,
      'lastPaymentUpdateDate': lastPaymentUpdateDate != null
          ? Timestamp.fromDate(lastPaymentUpdateDate!)
          : null,
    };
  }
}
