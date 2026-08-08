enum RegistrationType { driver, houseOwner }

enum RegistrationStatus { pending, approved, rejected }

class RegistrationRequestEntity {
  final String id;
  final RegistrationType type;
  final RegistrationStatus status;
  final String name;
  final String mobile;
  final String nic;
  final String email;
  final String? address;
  final String? houseNumber;
  final DateTime submittedAt;

  RegistrationRequestEntity({
    required this.id,
    required this.type,
    required this.status,
    required this.name,
    required this.mobile,
    required this.nic,
    required this.email,
    this.address,
    this.houseNumber,
    required this.submittedAt,
  });
}
