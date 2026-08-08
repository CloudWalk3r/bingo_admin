class DriverEntity {
  final String id;
  final String nic;
  final String name;
  final String mobile;
  final String email;
  final int age;
  final DateTime lastLicenseRenewed;
  final DateTime workStartedDate;

  DriverEntity({
    required this.id,
    required this.nic,
    required this.name,
    required this.mobile,
    required this.email,
    required this.age,
    required this.lastLicenseRenewed,
    required this.workStartedDate,
  });
}
