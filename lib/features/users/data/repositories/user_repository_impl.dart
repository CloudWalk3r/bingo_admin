import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/user_repository.dart';
import '../models/user_model.dart';

class UserRepositoryImpl implements UserRepository {
  final FirebaseFirestore _db;
  final DatabaseReference _houseOwnersRef;

  UserRepositoryImpl({FirebaseFirestore? db, FirebaseDatabase? rtdb})
      : _db = db ?? FirebaseFirestore.instance,
        _houseOwnersRef = (rtdb ?? FirebaseDatabase.instance).ref('House_Owner_Profiles/House_Profile');

  @override
  Stream<List<UserEntity>> watchAll() {
    // House owners register through the BinGo app straight into the
    // Realtime Database, so that's the authoritative list of who exists.
    // Firestore `users` only holds admin-set payment metadata per owner.
    return _houseOwnersRef.onValue.asyncMap((event) async {
      final raw = event.snapshot.value;
      if (raw == null) return <UserEntity>[];
      final profiles = Map<Object?, Object?>.from(raw as Map);

      final entries = profiles.entries.toList();
      final paymentDocs = await Future.wait(
        entries.map((e) => _db.collection('users').doc(e.key.toString()).get()),
      );
      final registrationDocs = await Future.wait(
        entries.map((e) => _db.collection('registration_requests').doc('house_owner_${e.key}').get()),
      );

      final users = <UserEntity>[];
      for (var i = 0; i < entries.length; i++) {
        final value = entries[i].value;
        if (value is! Map) continue;

        // Only list house owners who are approved — or who registered
        // before this approval flow existed (no request doc at all).
        final regDoc = registrationDocs[i];
        if (regDoc.exists && regDoc.data()?['status'] != 'approved') continue;

        final profileInfo = Map<Object?, Object?>.from(value['Profile_Info'] as Map? ?? {});
        users.add(UserModel.fromRealtimeProfile(
          entries[i].key.toString(),
          profileInfo,
          paymentDocs[i].exists ? paymentDocs[i].data() as Map<String, dynamic> : null,
        ));
      }
      return users;
    });
  }

  @override
  Future<void> updatePaymentStatus(String userId, bool isPaid) {
    return _db.collection('users').doc(userId).set({
      'isPaidManually': isPaid,
      'lastPaymentUpdateDate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
