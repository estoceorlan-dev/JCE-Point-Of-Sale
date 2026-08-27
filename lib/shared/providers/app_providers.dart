import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../models/business_context.dart';
import '../models/permission.dart';
export '../../core/sync/sync_controller.dart' show syncStateProvider;

final currentBranchIdProvider = Provider<String?>((ref) {
  return ref.watch(authControllerProvider).asData?.value?.activeBranchId;
});

final currentOrganizationIdProvider = Provider<String?>((ref) {
  return ref.watch(authControllerProvider).asData?.value?.activeOrganizationId;
});

final currentPermissionsProvider = Provider<Set<AppPermission>>((ref) {
  return ref.watch(authControllerProvider).asData?.value?.permissions ??
      const <AppPermission>{};
});

final businessContextProvider = Provider<BusinessContext?>((ref) {
  final session = ref.watch(authControllerProvider).asData?.value;
  if (session == null) {
    return null;
  }
  return BusinessContext(
    organizationId: session.activeOrganizationId,
    branchId: session.activeBranchId,
    actorUserId: session.activeOrganization.appUserId,
  );
});
