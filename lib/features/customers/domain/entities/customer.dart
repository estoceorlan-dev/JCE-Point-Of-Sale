import 'loyalty_account.dart';

enum CustomerStatus {
  active,
  archived,
  anonymized,
  merged;

  String get databaseValue => name;

  String get label => switch (this) {
    active => 'Active',
    archived => 'Archived',
    anonymized => 'Anonymized',
    merged => 'Merged',
  };

  static CustomerStatus fromDatabase(String value) => values.firstWhere(
    (status) => status.databaseValue == value,
    orElse: () => CustomerStatus.archived,
  );
}

class CustomerAddressDraft {
  const CustomerAddressDraft({
    required this.label,
    required this.lineOne,
    required this.city,
    this.id,
    this.recipientName,
    this.lineTwo,
    this.province,
    this.postalCode,
    this.countryCode = 'PH',
    this.isPrimary = false,
  });

  final String? id;
  final String label;
  final String? recipientName;
  final String lineOne;
  final String? lineTwo;
  final String city;
  final String? province;
  final String? postalCode;
  final String countryCode;
  final bool isPrimary;
}

class CustomerDraft {
  const CustomerDraft({
    required this.displayName,
    this.email,
    this.phone,
    this.birthDate,
    this.marketingConsent = false,
    this.enableLoyalty = false,
    this.allowDuplicateContact = false,
    this.addresses = const [],
    this.operationId,
  });

  final String displayName;
  final String? email;
  final String? phone;
  final DateTime? birthDate;
  final bool marketingConsent;
  final bool enableLoyalty;
  final bool allowDuplicateContact;
  final List<CustomerAddressDraft> addresses;
  final String? operationId;
}

class CustomerAddress {
  const CustomerAddress({
    required this.id,
    required this.label,
    required this.lineOne,
    required this.city,
    required this.countryCode,
    required this.isPrimary,
    required this.version,
    this.recipientName,
    this.lineTwo,
    this.province,
    this.postalCode,
  });

  final String id;
  final String label;
  final String? recipientName;
  final String lineOne;
  final String? lineTwo;
  final String city;
  final String? province;
  final String? postalCode;
  final String countryCode;
  final bool isPrimary;
  final int version;

  String get formatted => [
    lineOne,
    if (lineTwo != null) lineTwo!,
    city,
    if (province != null) province!,
    if (postalCode != null) postalCode!,
    countryCode,
  ].join(', ');
}

class CustomerSummary {
  const CustomerSummary({
    required this.id,
    required this.customerNumber,
    required this.displayName,
    required this.status,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.email,
    this.phone,
    this.birthDate,
    this.marketingConsent = false,
    this.mergedIntoCustomerId,
    this.loyaltyPoints,
  });

  final String id;
  final String customerNumber;
  final String displayName;
  final String? email;
  final String? phone;
  final DateTime? birthDate;
  final bool marketingConsent;
  final CustomerStatus status;
  final String? mergedIntoCustomerId;
  final int version;
  final int? loyaltyPoints;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get canTransact => status == CustomerStatus.active;
}

class CustomerNote {
  const CustomerNote({
    required this.id,
    required this.body,
    required this.createdByUserId,
    required this.createdAt,
  });

  final String id;
  final String body;
  final String createdByUserId;
  final DateTime createdAt;
}

class CustomerPurchase {
  const CustomerPurchase({
    required this.saleId,
    required this.receiptNumber,
    required this.status,
    required this.totalMinor,
    required this.completedAt,
  });

  final String saleId;
  final String receiptNumber;
  final String status;
  final int totalMinor;
  final DateTime completedAt;
}

class CustomerProfile {
  const CustomerProfile({
    required this.customer,
    required this.addresses,
    required this.notes,
    required this.purchases,
    this.loyaltyAccount,
  });

  final CustomerSummary customer;
  final List<CustomerAddress> addresses;
  final List<CustomerNote> notes;
  final List<CustomerPurchase> purchases;
  final LoyaltyAccount? loyaltyAccount;
}
