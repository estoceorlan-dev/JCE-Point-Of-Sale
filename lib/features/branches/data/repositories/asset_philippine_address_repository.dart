import '../../domain/entities/philippine_address_catalog.dart';
import '../../domain/repositories/philippine_address_repository.dart';
import '../data_sources/philippine_address_asset_data_source.dart';

class AssetPhilippineAddressRepository implements PhilippineAddressRepository {
  const AssetPhilippineAddressRepository({required this.dataSource});

  final PhilippineAddressAssetDataSource dataSource;

  @override
  Future<PhilippineAddressCatalog> loadCatalog() async {
    final catalog = await dataSource.loadCatalog();
    return catalog.toDomain();
  }
}
