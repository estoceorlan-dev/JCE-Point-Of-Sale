import 'dart:convert';

import 'package:flutter/services.dart';

import '../dtos/philippine_address_catalog_dto.dart';

class PhilippineAddressAssetDataSource {
  const PhilippineAddressAssetDataSource({required this.assetBundle});

  static const assetPath = 'assets/data/philippine_address_catalog.json';

  final AssetBundle assetBundle;

  Future<PhilippineAddressCatalogDto> loadCatalog() async {
    final encoded = await assetBundle.loadString(assetPath);
    final json = jsonDecode(encoded) as Map<String, Object?>;
    return PhilippineAddressCatalogDto.fromJson(json);
  }
}
