import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../shared/models/business_context.dart';
import '../config/app_config.dart';
import '../database/database_provider.dart';
import '../remote/firebase_functions_provider.dart';
import '../remote/pos_bootstrap_remote_data_source.dart';
import 'drift_pos_bootstrap_repository.dart';
import 'pos_bootstrap_repository.dart';

final posBootstrapRepositoryProvider = Provider<PosBootstrapRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  return DriftPosBootstrapRepository(
    database: ref.watch(appDatabaseProvider),
    remote: CloudFunctionsPosBootstrapRemoteDataSource(
      functions: ref.watch(firebaseFunctionsProvider),
      functionName: config.posBootstrapFunctionName,
    ),
  );
});

final posBootstrapProgressProvider = StreamProvider<PosBootstrapProgress>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  if (config.enableDemoAuth || !config.enablePosSyncV2) {
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
