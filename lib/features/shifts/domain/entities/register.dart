class Register {
  const Register({
    required this.id,
    required this.organizationId,
    required this.branchId,
    required this.code,
    required this.name,
    required this.isActive,
    required this.version,
    this.assignedDeviceId,
  });

  final String id;
  final String organizationId;
  final String branchId;
  final String code;
  final String name;
  final String? assignedDeviceId;
  final bool isActive;
  final int version;

  bool isAssignedTo(String deviceId) => assignedDeviceId == deviceId;
}

class RegisterDraft {
  const RegisterDraft({required this.code, required this.name});

  final String code;
  final String name;
}
