// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'outbox_dao.dart';

// ignore_for_file: type=lint
mixin _$OutboxDaoMixin on DatabaseAccessor<AppDatabase> {
  $SyncOutboxEntriesTable get syncOutboxEntries =>
      attachedDatabase.syncOutboxEntries;
  $SyncOutboxDependenciesTable get syncOutboxDependencies =>
      attachedDatabase.syncOutboxDependencies;
  OutboxDaoManager get managers => OutboxDaoManager(this);
}

class OutboxDaoManager {
  final _$OutboxDaoMixin _db;
  OutboxDaoManager(this._db);
  $$SyncOutboxEntriesTableTableManager get syncOutboxEntries =>
      $$SyncOutboxEntriesTableTableManager(
        _db.attachedDatabase,
        _db.syncOutboxEntries,
      );
  $$SyncOutboxDependenciesTableTableManager get syncOutboxDependencies =>
      $$SyncOutboxDependenciesTableTableManager(
        _db.attachedDatabase,
        _db.syncOutboxDependencies,
      );
}
