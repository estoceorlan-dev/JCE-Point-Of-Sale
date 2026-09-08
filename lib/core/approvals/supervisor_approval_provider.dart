import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/unavailable_supervisor_approval_service.dart';
import 'domain/supervisor_approval_service.dart';

// Intentionally cannot be enabled by a remote flag while security work is open.
final supervisorApprovalServiceProvider = Provider<SupervisorApprovalService>(
  (ref) => const UnavailableSupervisorApprovalService(),
);
