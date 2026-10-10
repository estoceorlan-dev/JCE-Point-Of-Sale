// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_entity_version_dao.dart';

// ignore_for_file: type=lint
mixin _$SyncEntityVersionDaoMixin on DatabaseAccessor<AppDatabase> {
  $SyncEntityVersionsTable get syncEntityVersions =>
      attachedDatabase.syncEntityVersions;
  SyncEntityVersionDaoManager get managers => SyncEntityVersionDaoManager(this);
}

class SyncEntityVersionDaoManager {
  final _$SyncEntityVersionDaoMixin _db;
  SyncEntityVersionDaoManager(this._db);
  $$SyncEntityVersionsTableTableManager get syncEntityVersions =>
      $$SyncEntityVersionsTableTableManager(
        _db.attachedDatabase,
        _db.syncEntityVersions,
      );
}
