import '../entities/request_entity.dart';
import '../../../drivers/domain/entities/driver_entity.dart';
import '../../../../core/constants/enums.dart';

abstract class RequestRepository {
  Stream<List<RequestEntity>> watchAll();
  Stream<List<RequestEntity>> watchByDate(DateTime date);
  Future<void> addRequest(RequestEntity request);
  Future<void> updateStatus(String requestId, RequestStatus status);
  Future<void> assignDriver(String requestId, DriverEntity driver);
}
