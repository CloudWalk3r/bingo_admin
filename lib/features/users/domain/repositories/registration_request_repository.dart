import '../entities/registration_request_entity.dart';

abstract class RegistrationRequestRepository {
  Stream<List<RegistrationRequestEntity>> watchPending();
  Future<void> approve(RegistrationRequestEntity request);
  Future<void> reject(RegistrationRequestEntity request);
}
