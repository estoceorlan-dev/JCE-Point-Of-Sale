import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/database/daos/metadata_dao.dart';
import '../../../../core/database/daos/outbox_dao.dart';
import '../../../../core/database/models/outbox_command.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/device_registration_repository.dart';

class CloudFunctionsDeviceRegistrationRepository
    implements DeviceRegistrationRepository {
  const CloudFunctionsDeviceRegistrationRepository({
    required FirebaseFunctions functions,
    required String functionName,
    required MetadataDao metadataDao,
    required OutboxDao outboxDao,
    required IdGenerator idGenerator,
    required AppClock clock,
  }) : _functions = functions,
       _functionName = functionName,
       _metadataDao = metadataDao,
       _outboxDao = outboxDao,
       _idGenerator = idGenerator,
       _clock = clock;

  static const _deviceIdKey = 'device.id';

  final FirebaseFunctions _functions;
  final String _functionName;
  final MetadataDao _metadataDao;
  final OutboxDao _outboxDao;
  final IdGenerator _idGenerator;
  final AppClock _clock;

  @override
  Future<String> deviceId() async {
    final existing = await _metadataDao.readValue(_deviceIdKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing;
    }
    final created = _idGenerator.newId();
    await _metadataDao.writeValue(
      key: _deviceIdKey,
      value: created,
      updatedAt: _clock.nowUtc(),
    );
    return created;
  }

  @override
  Future<void> register(AuthSession session) async {
    final id = await deviceId();
    final payload = <String, Object?>{
      'deviceId': id,
      'platform': defaultTargetPlatform.name,
      'organizationId': session.activeOrganizationId,
      'branchId': session.activeBranchId,
    };
    try {
      await _functions.httpsCallable(_functionName).call(payload);
    } catch (_) {
      await _outboxDao.enqueue(
        OutboxCommand(
          operationId: _idGenerator.newId(),
          organizationId: session.activeOrganizationId,
          branchId: session.activeBranchId,
          actorUserId: session.activeOrganization.appUserId,
          commandType: 'device.register',
          aggregateType: 'device',
          aggregateId: id,
          payload: payload,
          createdAt: _clock.nowUtc(),
        ),
      );
    }
  }
}
