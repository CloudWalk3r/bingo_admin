import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart' hide Query;
import '../../../../core/utils/stream_combine.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/user_repository.dart';
import '../models/user_model.dart';

class UserRepositoryImpl implements UserRepository {
  /// Prefix the app uses for house owner registration request document ids.
  static const _houseOwnerRequestPrefix = 'house_owner_';

  final FirebaseFirestore _db;
  final DatabaseReference _houseOwnersRef;

  UserRepositoryImpl({FirebaseFirestore? db, FirebaseDatabase? rtdb})
      : _db = db ?? FirebaseFirestore.instance,
        _houseOwnersRef = (rtdb ?? FirebaseDatabase.instance).ref('House_Owner_Profiles/House_Profile');

  @override
  Stream<List<UserEntity>> watchAll() {
    // House owners register through the BinGo app straight into the
    // Realtime Database, so that's the authoritative list of who exists.
    // Firestore `users` only holds admin-set payment metadata per owner, and
    // `registration_requests` says whether the owner was approved.
    //
    // All three are watched as whole collections and joined in memory: three
    // subscriptions total, no matter how many house owners exist. Reading the
    // two Firestore docs per owner instead costs 2xN round trips on every
    // Realtime Database event, which is what made this screen slow to load.
    return combineLatest3(
      _houseOwnersRef.onValue,
      _db.collection('users').snapshots(),
      _houseOwnerRequests().snapshots(),
      _joinUsers,
    );
  }

  /// Registration requests belonging to house owners, matched by the document
  /// id prefix the app writes (`house_owner_<owner id>`). The upper bound is
  /// the prefix followed by the highest code point, which is the standard
  /// Firestore way to express "document id starts with this prefix".
  Query<Map<String, dynamic>> _houseOwnerRequests() {
    return _db
        .collection('registration_requests')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: _houseOwnerRequestPrefix)
        .where(FieldPath.documentId, isLessThan: '$_houseOwnerRequestPrefix\u{10FFFF}');
  }

  List<UserEntity> _joinUsers(
    DatabaseEvent profileEvent,
    QuerySnapshot<Map<String, dynamic>> paymentSnapshot,
    QuerySnapshot<Map<String, dynamic>> requestSnapshot,
  ) {
    final raw = profileEvent.snapshot.value;
    if (raw is! Map) return const <UserEntity>[];

    final payments = {
      for (final doc in paymentSnapshot.docs) doc.id: doc.data(),
    };
    final requestStatuses = {
      for (final doc in requestSnapshot.docs) doc.id: doc.data()['status'] as String?,
    };

    final users = <UserEntity>[];
    raw.forEach((key, value) {
      if (value is! Map) return;
      final ownerId = key.toString();

      // Only list house owners who are approved — or who registered before
      // this approval flow existed (no request document at all).
      final status = requestStatuses['$_houseOwnerRequestPrefix$ownerId'];
      final hasRequest = requestStatuses.containsKey('$_houseOwnerRequestPrefix$ownerId');
      if (hasRequest && status != 'approved') return;

      final profileInfo = value['Profile_Info'];
      users.add(UserModel.fromRealtimeProfile(
        ownerId,
        profileInfo is Map ? profileInfo : const {},
        payments[ownerId],
      ));
    });

    users.sort((a, b) => a.ownerName.toLowerCase().compareTo(b.ownerName.toLowerCase()));
    return users;
  }

  @override
  Future<void> updatePaymentStatus(String userId, bool isPaid) {
    return _db.collection('users').doc(userId).set({
      'isPaidManually': isPaid,
      'lastPaymentUpdateDate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
