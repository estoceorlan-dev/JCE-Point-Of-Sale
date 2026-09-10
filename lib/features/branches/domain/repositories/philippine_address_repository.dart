import '../entities/philippine_address_catalog.dart';

abstract interface class PhilippineAddressRepository {
  Future<PhilippineAddressCatalog> loadCatalog();
}
