import 'dart:async';
import '../../features/auth/presentation/providers/native_auth_providers.dart';
import '../remote/node_bootstrap_data_source.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../shared/models/business_context.dart';
import '../config/app_config.dart';
import '../database/database_provider.dart';
import 'drift_pos_bootstrap_repository.dart';
import 'pos_bootstrap_repository.dart';

final posBootstrapRepositoryProvider = Provider<PosBootstrapRepository>((ref) {
  return DriftPosBootstrapRepository(
    database: ref.watch(appDatabaseProvider),
    remote: NodeBootstrapDataSource(
      ref.watch(nativeApiSessionRepositoryProvider),
    ),
  );
});

final posBootstrapProgressProvider = StreamProvider<PosBootstrapProgress>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  if (config.enableDemoAuth) {
    return Stream.value(
      const PosBootstrapProgress(status: PosBootstrapStatus.ready),
    );
  }
  final session = ref.watch(authControllerProvider).asData?.value;
  if (session == null) {
    return Stream.value(
      const PosBootstrapProgress(status: PosBootstrapStatus.notProvisioned),
    );
  }
  final context = BusinessContext(
    organizationId: session.activeOrganizationId,
    branchId: session.activeBranchId,
    actorUserId: session.activeOrganization.appUserId,
  );
  final repository = ref.watch(posBootstrapRepositoryProvider);
  unawaited(repository.provision(context));
  return repository.watchProgress(context);
});
