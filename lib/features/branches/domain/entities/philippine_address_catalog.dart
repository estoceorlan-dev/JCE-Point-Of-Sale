class PhilippineAddressCatalog {
  const PhilippineAddressCatalog({
    required this.country,
    required this.timezone,
    required this.release,
    required this.areas,
  });

  final String country;
  final String timezone;
  final String release;
  final List<PhilippineAddressArea> areas;

  PhilippineAddressArea? areaNamed(String? name) {
    final normalized = name?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    for (final area in areas) {
      if (area.name.toLowerCase() == normalized) return area;
    }
    return null;
  }
}

class PhilippineAddressArea {
  const PhilippineAddressArea({required this.name, required this.localities});

  final String name;
  final List<PhilippineLocality> localities;
}

class PhilippineLocality {
  const PhilippineLocality({required this.code, required this.name});

  final String code;
  final String name;
}
