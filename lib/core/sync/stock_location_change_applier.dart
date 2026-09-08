import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'remote_change_envelope.dart';

class StockLocationChangeApplier {
  const StockLocationChangeApplier(this.database);
  final AppDatabase database;

  Future<bool> hasPending(
    String organizationId,
    String branchId, {
    String? id,
  }) async {
    final query = database.select(database.syncOutboxEntries)
      ..where(
        (row) =>
            row.organizationId.equals(organizationId) &
            row.branchId.equals(branchId) &
            row.aggregateType.equals('stock_location') &
            row.status.isNotIn(const ['succeeded', 'discarded']),
      );
    if (id != null) query.where((row) => row.aggregateId.equals(id));
    return await (query..limit(1)).getSingleOrNull() != null;
  }

  Future<void> apply(RemoteChangeEnvelope envelope) async {
    final raw = envelope.result['stockLocation'];
    if (raw is! Map) {
      throw const FormatException('Missing stock location projection.');
    }
    final branch = envelope.change.branchId;
    if (branch == null) {
      throw const FormatException('Location branch is required.');
    }
    await database.transaction(() async {
      final demoted = envelope.result['demotedLocations'];
      if (demoted is List) {
        for (final row in demoted) {
          if (row is! Map) {
            throw const FormatException('Invalid default location projection.');
          }
          await applyRow(
            envelope.change.organizationId,
            branch,
            row,
            envelope.change.occurredAt,
          );
        }
      } else if (raw['is_default'] == true ||
          envelope.commandPayload['isDefault'] == true) {
        // Compatibility with creation events from the schema-15 backend.
        final defaults =
            await (database.select(database.stockLocations)..where(
                  (row) =>
                      row.organizationId.equals(
                        envelope.change.organizationId,
                      ) &
                      row.branchId.equals(branch) &
                      row.isDefault.equals(true) &
                      row.id.equals(envelope.change.aggregateId).not(),
                ))
                .get();
        for (final row in defaults) {
          if (await hasPending(row.organizationId, branch, id: row.id)) {
            continue;
          }
          // Only demote a projection older than this legacy event.
          if (row.updatedAt.isAfter(envelope.change.occurredAt)) continue;
          await (database.update(
            database.stockLocations,
          )..where((value) => value.id.equals(row.id))).write(
            StockLocationsCompanion(
              isDefault: const Value(false),
              version: Value(row.version + 1),
              updatedAt: Value(envelope.change.occurredAt),
            ),
          );
        }
      }
      await applyRow(
        envelope.change.organizationId,
        branch,
        {
          'id': envelope.change.aggregateId,
          'code': envelope.commandPayload['code'],
          'name': envelope.commandPayload['name'],
          'location_type': envelope.commandPayload['locationType'],
          'is_default': envelope.commandPayload['isDefault'] ?? false,
          'is_active': true,
          'version': envelope.change.version,
          ...raw,
        },
        envelope.change.occurredAt,
        expectedId: envelope.change.aggregateId,
      );
    });
  }

  Future<void> applyRow(
    String organizationId,
    String branchId,
    Map row,
    DateTime now, {
    String? expectedId,
    bool replaceLocal = false,
  }) async {
    final id = row['id'];
    final version = row['version'];
    if (id is! String ||
        id.isEmpty ||
        version is! int ||
        version < 0 ||
        (expectedId != null && id != expectedId) ||
        (row['organization_id'] != null &&
            row['organization_id'] != organizationId) ||
        (row['branch_id'] != null && row['branch_id'] != branchId)) {
      throw const FormatException('Invalid stock location scope/version.');
    }
    if (await hasPending(organizationId, branchId, id: id)) return;
    final existing = await (database.select(
      database.stockLocations,
    )..where((value) => value.id.equals(id))).getSingleOrNull();
    if (existing != null &&
        (existing.organizationId != organizationId ||
            existing.branchId != branchId)) {
      throw const FormatException(
        'Location identity belongs to another scope.',
      );
    }
    final known = await database.syncEntityVersionDao.readVersion(
      organizationId: organizationId,
      entityType: 'stock_location',
      entityId: id,
    );
    if (version < known) {
      if (replaceLocal) {
        throw const FormatException(
          'The snapshot is older than the last synchronized location.',
        );
      }
      return;
    }
    if (!replaceLocal && existing != null && version < existing.version) return;
    if (row['code'] is! String ||
        row['name'] is! String ||
        row['location_type'] is! String ||
        row['is_active'] is! bool ||
        row['is_default'] is! bool) {
      throw const FormatException('Incomplete stock location projection.');
    }
    DateTime? date(Object? value) =>
        value == null ? null : DateTime.parse(value.toString()).toUtc();
    await database
        .into(database.stockLocations)
        .insertOnConflictUpdate(
          StockLocationsCompanion.insert(
            id: id,
            organizationId: organizationId,
            branchId: branchId,
            code: row['code'] as String,
            name: row['name'] as String,
            locationType: Value(row['location_type'] as String),
            isDefault: Value(row['is_default'] as bool),
            isActive: Value(row['is_active'] as bool),
            version: Value(version),
            deletedAt: Value(date(row['deleted_at'])),
            createdAt: date(row['created_at']) ?? existing?.createdAt ?? now,
            updatedAt: date(row['updated_at']) ?? now,
          ),
        );
    await database.syncEntityVersionDao.save(
      organizationId: organizationId,
      branchId: branchId,
      entityType: 'stock_location',
      entityId: id,
      remoteVersion: version,
      operationId: 'stock-location-projection:$id:$version',
      updatedAt: now,
    );
  }
}
