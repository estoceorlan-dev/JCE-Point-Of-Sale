class SupplierContactDraft {
  const SupplierContactDraft({
    required this.name,
    this.role,
    this.email,
    this.phone,
    this.isPrimary = false,
  });

  final String name;
  final String? role;
  final String? email;
  final String? phone;
  final bool isPrimary;
}

class SupplierDraft {
  const SupplierDraft({
    required this.code,
    required this.name,
    this.taxIdentifier,
    this.paymentTermsDays = 0,
    this.contacts = const [],
    this.operationId,
  });

  final String code;
  final String name;
  final String? taxIdentifier;
  final int paymentTermsDays;
  final List<SupplierContactDraft> contacts;
  final String? operationId;
}

class SupplierContact {
  const SupplierContact({
    required this.id,
    required this.name,
    required this.isPrimary,
    this.role,
    this.email,
    this.phone,
  });

  final String id;
  final String name;
  final String? role;
  final String? email;
  final String? phone;
  final bool isPrimary;
}

class Supplier {
  const Supplier({
    required this.id,
    required this.code,
    required this.name,
    required this.paymentTermsDays,
    required this.isActive,
    required this.version,
    required this.contacts,
    required this.createdAt,
    required this.updatedAt,
    this.taxIdentifier,
  });

  final String id;
  final String code;
  final String name;
  final String? taxIdentifier;
  final int paymentTermsDays;
  final bool isActive;
  final int version;
  final List<SupplierContact> contacts;
  final DateTime createdAt;
  final DateTime updatedAt;
}
