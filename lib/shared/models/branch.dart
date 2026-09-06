class Branch {
  const Branch({
    required this.id,
    required this.organizationId,
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
    this.isActive = true,
    this.version = 0,
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
}
