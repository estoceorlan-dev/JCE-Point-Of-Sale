// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_conflict_dao.dart';

// ignore_for_file: type=lint
mixin _$SyncConflictDaoMixin on DatabaseAccessor<AppDatabase> {
  $SyncConflictsTable get syncConflicts => attachedDatabase.syncConflicts;
  SyncConflictDaoManager get managers => SyncConflictDaoManager(this);
}

class SyncConflictDaoManager {
  final _$SyncConflictDaoMixin _db;
  SyncConflictDaoManager(this._db);
  $$SyncConflictsTableTableManager get syncConflicts =>
      $$SyncConflictsTableTableManager(_db.attachedDatabase, _db.syncConflicts);
}
