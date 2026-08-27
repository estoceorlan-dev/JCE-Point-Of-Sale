import '../database/app_database.dart';
import '../remote/remote_sync_data_source.dart';
import 'catalog_change_applier.dart';
import 'operations_change_applier.dart';
import 'remote_change_envelope.dart';

abstract interface class RemoteChangeApplier {
  Future<void> apply(RemoteChange change);
}

class DriftRemoteChangeApplier implements RemoteChangeApplier {
  DriftRemoteChangeApplier(AppDatabase database)
    : _catalog = CatalogChangeApplier(database),
      _operations = OperationsChangeApplier(database);

  final CatalogChangeApplier _catalog;
  final OperationsChangeApplier _operations;

  @override
  Future<void> apply(RemoteChange change) async {
    final envelope = RemoteChangeEnvelope.parse(change);
    if (await _catalog.apply(envelope)) return;
    if (await _operations.apply(envelope)) return;
    throw FormatException(
      'Unsupported remote command ${envelope.commandType}.',
    );
  }
}
