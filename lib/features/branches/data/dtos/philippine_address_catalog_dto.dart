import '../../domain/entities/philippine_address_catalog.dart';

class PhilippineAddressCatalogDto {
  const PhilippineAddressCatalogDto({
    required this.country,
    required this.timezone,
    required this.release,
    required this.areas,
  });

  factory PhilippineAddressCatalogDto.fromJson(Map<String, Object?> json) {
    return PhilippineAddressCatalogDto(
      country: json['country']! as String,
      timezone: json['timezone']! as String,
      release: json['release']! as String,
      areas: (json['areas']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .map(PhilippineAddressAreaDto.fromJson)
          .toList(growable: false),
    );
  }

  final String country;
  final String timezone;
  final String release;
  final List<PhilippineAddressAreaDto> areas;

  PhilippineAddressCatalog toDomain() => PhilippineAddressCatalog(
    country: country,
    timezone: timezone,
    release: release,
    areas: areas.map((area) => area.toDomain()).toList(growable: false),
  );
}

class PhilippineAddressAreaDto {
  const PhilippineAddressAreaDto({
    required this.name,
    required this.localities,
  });

  factory PhilippineAddressAreaDto.fromJson(Map<String, Object?> json) {
    return PhilippineAddressAreaDto(
      name: json['name']! as String,
      localities: (json['localities']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .map(PhilippineLocalityDto.fromJson)
          .toList(growable: false),
    );
  }

  final String name;
  final List<PhilippineLocalityDto> localities;

  PhilippineAddressArea toDomain() => PhilippineAddressArea(
    name: name,
    localities: localities
        .map((locality) => locality.toDomain())
        .toList(growable: false),
  );
}

class PhilippineLocalityDto {
  const PhilippineLocalityDto({required this.code, required this.name});

  factory PhilippineLocalityDto.fromJson(Map<String, Object?> json) {
    return PhilippineLocalityDto(
      code: json['code']! as String,
      name: json['name']! as String,
    );
  }

  final String code;
  final String name;

  PhilippineLocality toDomain() => PhilippineLocality(code: code, name: name);
}
