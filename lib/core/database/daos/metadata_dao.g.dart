// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'metadata_dao.dart';

// ignore_for_file: type=lint
mixin _$MetadataDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocalMetadataTable get localMetadata => attachedDatabase.localMetadata;
  MetadataDaoManager get managers => MetadataDaoManager(this);
}

class MetadataDaoManager {
  final _$MetadataDaoMixin _db;
  MetadataDaoManager(this._db);
  $$LocalMetadataTableTableManager get localMetadata =>
      $$LocalMetadataTableTableManager(_db.attachedDatabase, _db.localMetadata);
}
