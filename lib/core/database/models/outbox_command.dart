import 'dart:convert';

import 'outbox_state.dart';

class OutboxCommand {
  const OutboxCommand({
    required this.operationId,
    required this.commandType,
    required this.aggregateType,
    required this.aggregateId,
    required this.payload,
    required this.createdAt,
    this.organizationId,
    this.branchId,
    this.actorUserId,
    this.state = OutboxState.pending,
  });

  final String operationId;
  final String? organizationId;
  final String? branchId;
  final String? actorUserId;
  final String commandType;
  final String aggregateType;
  final String aggregateId;
  final Map<String, Object?> payload;
  final DateTime createdAt;
  final OutboxState state;

  String get payloadJson => jsonEncode(payload);
}
