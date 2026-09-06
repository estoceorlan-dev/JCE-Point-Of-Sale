class BranchProfile {
  const BranchProfile({
    required this.id,
    required this.organizationId,
    required this.code,
    required this.name,
    required this.timezone,
    required this.isActive,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.addressLineOne,
    this.addressLineTwo,
    this.city,
    this.province,
    this.postalCode,
    this.phone,
    this.email,
    this.receiptDisplayName,
    this.deletedAt,
    this.staffCount = 0,
    this.registerCount = 0,
    this.pendingOperations = 0,
    this.openShifts = 0,
  });

  final String id;
  final String organizationId;
  final String code;
  final String name;
  final String timezone;
  final String? addressLineOne;
  final String? addressLineTwo;
  final String? city;
  final String? province;
  final String? postalCode;
  final String? phone;
  final String? email;
  final String? receiptDisplayName;
  final bool isActive;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int staffCount;
  final int registerCount;
  final int pendingOperations;
  final int openShifts;
}

class BranchDraft {
  const BranchDraft({
    required this.code,
    required this.name,
    required this.timezone,
    this.addressLineOne,
    this.addressLineTwo,
    this.city,
    this.province,
    this.postalCode,
    this.phone,
    this.email,
    this.receiptDisplayName,
  });

  final String code;
  final String name;
  final String timezone;
  final String? addressLineOne;
  final String? addressLineTwo;
  final String? city;
  final String? province;
  final String? postalCode;
  final String? phone;
  final String? email;
  final String? receiptDisplayName;

  BranchDraft normalized() => BranchDraft(
    code: code.trim().toUpperCase(),
    name: name.trim(),
    timezone: timezone.trim(),
    addressLineOne: _blankToNull(addressLineOne),
    addressLineTwo: _blankToNull(addressLineTwo),
    city: _blankToNull(city),
    province: _blankToNull(province),
    postalCode: _blankToNull(postalCode),
    phone: _blankToNull(phone),
    email: _blankToNull(email)?.toLowerCase(),
    receiptDisplayName: _blankToNull(receiptDisplayName),
  );
}

class BranchQuery {
  const BranchQuery({this.search = '', this.includeArchived = false});

  final String search;
  final bool includeArchived;

  @override
  bool operator ==(Object other) =>
      other is BranchQuery &&
      other.search == search &&
      other.includeArchived == includeArchived;
  @override
  int get hashCode => Object.hash(search, includeArchived);
}

String? _blankToNull(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
