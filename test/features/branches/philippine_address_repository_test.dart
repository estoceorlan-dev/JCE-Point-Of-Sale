import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/features/branches/data/data_sources/philippine_address_asset_data_source.dart';
import 'package:jce_pos/features/branches/data/repositories/asset_philippine_address_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the bundled 2Q 2026 Philippine address catalog', () async {
    final repository = AssetPhilippineAddressRepository(
      dataSource: PhilippineAddressAssetDataSource(assetBundle: rootBundle),
    );

    final catalog = await repository.loadCatalog();
    final cebu = catalog.areaNamed('Cebu');

    expect(catalog.country, 'Philippines');
    expect(catalog.timezone, 'Asia/Manila');
    expect(catalog.release, '2Q 2026');
    expect(catalog.areas, hasLength(83));
    expect(cebu, isNotNull);
    expect(
      cebu!.localities.map((locality) => locality.name),
      containsAll(['Danao City', 'City of Cebu', 'City of Mandaue']),
    );
    expect(
      catalog
          .areaNamed('Davao del Norte')!
          .localities
          .map((locality) => locality.name),
      contains('Sawata'),
    );
  });
}
