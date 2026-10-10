import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart';
import 'package:jce_pos/features/auth/data/datasources/access_local_data_source.dart';
import 'package:jce_pos/features/auth/data/dto/node_access_mapper.dart';
import 'package:jce_pos/shared/models/permission.dart';

void main() {
  test(
    'two cashiers retain independent effective permissions in SQLite',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final cache = DriftAccessLocalDataSource(database);
      Map<String, dynamic> access(String user, List<String> permissions) => {
        'userId': user,
        'identityId': 'identity-$user',
        'email': '$user@example.test',
        'displayName': user,
        'organizationId': 'org',
        'organization': {
          'code': 'ORG',
          'name': 'Organization',
          'timezone': 'UTC',
        },
        'organizationPermissions': <String>[],
        'branches': [
          {
            'id': 'branch',
            'code': 'B',
            'name': 'Branch',
            'timezone': 'UTC',
            'permissions': permissions,
          },
        ],
      };
      await cache.replaceProfile(
        nodeAccessSession(access('first', ['sales.process'])).user,
      );
      await cache.replaceProfile(
        nodeAccessSession(access('second', ['products.manage'])).user,
      );
      final first = (await cache.findByFirebaseUid('identity-first'))!;
      final second = (await cache.findByFirebaseUid('identity-second'))!;
      expect(first.organizations.single.permissionsFor('branch'), {
        AppPermission.processSales,
      });
      expect(second.organizations.single.permissionsFor('branch'), {
        AppPermission.manageProducts,
      });
      await cache.replaceProfile(
        nodeAccessSession(access('second', ['sales.process'])).user,
      );
      expect(
        (await cache.findByFirebaseUid(
          'identity-first',
        ))!.organizations.single.permissionsFor('branch'),
        {AppPermission.processSales},
      );
    },
  );
}
