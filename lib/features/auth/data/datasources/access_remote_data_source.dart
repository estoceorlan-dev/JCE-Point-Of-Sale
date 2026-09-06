import 'package:cloud_functions/cloud_functions.dart';

import '../../../../shared/models/access_role.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/branch.dart';
import '../../../../shared/models/branch_access.dart';
import '../../../../shared/models/organization.dart';
import '../../../../shared/models/organization_access.dart';
import '../../../../shared/models/permission.dart';
import '../../../../shared/models/user_account_status.dart';

abstract interface class AccessRemoteDataSource {
  Future<AppUser?> fetchCurrentProfile({
    required String firebaseUid,
    required String email,
  });
}

class CloudFunctionsAccessRemoteDataSource implements AccessRemoteDataSource {
  const CloudFunctionsAccessRemoteDataSource({
    required FirebaseFunctions functions,
    required String functionName,
    String? acceptInvitationFunctionName,
  }) : _functions = functions,
       _functionName = functionName,
       _acceptInvitationFunctionName = acceptInvitationFunctionName;

  final FirebaseFunctions _functions;
  final String _functionName;
  final String? _acceptInvitationFunctionName;

  @override
  Future<AppUser?> fetchCurrentProfile({
    required String firebaseUid,
    required String email,
  }) async {
    try {
      final acceptFunction = _acceptInvitationFunctionName;
      if (acceptFunction != null) {
        await _functions
            .httpsCallable(acceptFunction)
            .call<Object?>(const <String, Object?>{});
      }
      final result = await _functions
          .httpsCallable(_functionName)
          .call<Object?>();
      final data = _asStringMap(result.data);
      if (data == null || data['user'] == null) {
        return null;
      }
      return _parseProfile(
        data,
        fallbackFirebaseUid: firebaseUid,
        fallbackEmail: email,
      );
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'not-found' ||
          error.code == 'permission-denied' ||
          error.code == 'unauthenticated') {
        throw AccessProfileRejectedException(error.code);
      }
      throw AccessProfileUnavailableException(error.code, cause: error);
    }
  }

  AppUser _parseProfile(
    Map<String, Object?> payload, {
    required String fallbackFirebaseUid,
    required String fallbackEmail,
  }) {
    final user = _requiredMap(payload, 'user');
    final organizationPayloads = _mapList(payload['organizations']);
    return AppUser(
      firebaseUid: _optionalString(user['firebaseUid']) ?? fallbackFirebaseUid,
      email: _optionalString(user['email']) ?? fallbackEmail,
      displayName:
          _optionalString(user['displayName']) ??
          _optionalString(user['email']) ??
          fallbackEmail,
      organizations: organizationPayloads
          .map(_parseOrganizationAccess)
          .toList(growable: false),
    );
  }

  OrganizationAccess _parseOrganizationAccess(Map<String, Object?> payload) {
    final organizationPayload = _requiredMap(payload, 'organization');
    final organization = Organization(
      id: _requiredString(organizationPayload, 'id'),
      code: _requiredString(organizationPayload, 'code'),
      name: _requiredString(organizationPayload, 'name'),
      timezone:
          _optionalString(organizationPayload['timezone']) ?? 'Asia/Manila',
    );
    return OrganizationAccess(
      appUserId: _requiredString(payload, 'appUserId'),
      organization: organization,
      status: UserAccountStatus.parse(
        _optionalString(payload['status']) ?? 'disabled',
      ),
      organizationRoles: _mapList(
        payload['organizationRoles'],
      ).map(_parseRole).toList(growable: false),
      branches: _mapList(payload['branches'])
          .map(
            (branchPayload) =>
                _parseBranchAccess(branchPayload, organization.id),
          )
          .toList(growable: false),
    );
  }

  BranchAccess _parseBranchAccess(
    Map<String, Object?> payload,
    String organizationId,
  ) {
    final branchPayload = _asStringMap(payload['branch']) ?? payload;
    return BranchAccess(
      branch: Branch(
        id: _requiredString(branchPayload, 'id'),
        organizationId: organizationId,
        code: _requiredString(branchPayload, 'code'),
        name: _requiredString(branchPayload, 'name'),
        timezone: _optionalString(branchPayload['timezone']) ?? 'Asia/Manila',
        addressLineOne: _optionalString(branchPayload['addressLineOne']),
        addressLineTwo: _optionalString(branchPayload['addressLineTwo']),
        city: _optionalString(branchPayload['city']),
        province: _optionalString(branchPayload['province']),
        postalCode: _optionalString(branchPayload['postalCode']),
        phone: _optionalString(branchPayload['phone']),
        email: _optionalString(branchPayload['email']),
        receiptDisplayName: _optionalString(
          branchPayload['receiptDisplayName'],
        ),
        isActive: branchPayload['isActive'] != false,
        version: int.tryParse('${branchPayload['version']}') ?? 0,
      ),
      roles: _mapList(payload['roles']).map(_parseRole).toList(growable: false),
    );
  }

  AccessRole _parseRole(Map<String, Object?> payload) {
    return AccessRole(
      id: _requiredString(payload, 'id'),
      code: _requiredString(payload, 'code'),
      name: _requiredString(payload, 'name'),
      permissions: {
        for (final code in _stringList(payload['permissions']))
          if (AppPermission.fromCode(code) case final permission?) permission,
      },
    );
  }
}

class AccessProfileRejectedException implements Exception {
  const AccessProfileRejectedException(this.reason);

  final String reason;
}

class AccessProfileUnavailableException implements Exception {
  const AccessProfileUnavailableException(this.reason, {this.cause});

  final String reason;
  final Object? cause;
}

Map<String, Object?> _requiredMap(Map<String, Object?> payload, String key) {
  final value = _asStringMap(payload[key]);
  if (value == null) {
    throw FormatException('Access profile is missing $key.');
  }
  return value;
}

String _requiredString(Map<String, Object?> payload, String key) {
  final value = _optionalString(payload[key]);
  if (value == null) {
    throw FormatException('Access profile is missing $key.');
  }
  return value;
}

String? _optionalString(Object? value) {
  final stringValue = value?.toString().trim();
  return stringValue == null || stringValue.isEmpty ? null : stringValue;
}

Map<String, Object?>? _asStringMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Map<String, Object?>> _mapList(Object? value) {
  if (value is! Iterable) {
    return const [];
  }
  return value
      .map(_asStringMap)
      .whereType<Map<String, Object?>>()
      .toList(growable: false);
}

List<String> _stringList(Object? value) {
  if (value is! Iterable) {
    return const [];
  }
  return value.map(_optionalString).whereType<String>().toList(growable: false);
}
