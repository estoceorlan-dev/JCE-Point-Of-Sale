library jce_pos_sql_connect;

import 'package:firebase_data_connect/firebase_data_connect.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

part 'pull_changes.dart';

part 'get_processed_operation.dart';

class PosConnectorConnector {
  PullChangesVariablesBuilder pullChanges({
    required String organizationId,
    required String branchId,
    required int afterSequence,
    required int limit,
  }) {
    return PullChangesVariablesBuilder(
      dataConnect,
      organizationId: organizationId,
      branchId: branchId,
      afterSequence: afterSequence,
      limit: limit,
    );
  }

  GetProcessedOperationVariablesBuilder getProcessedOperation({
    required String organizationId,
    required String branchId,
    required String operationId,
  }) {
    return GetProcessedOperationVariablesBuilder(
      dataConnect,
      organizationId: organizationId,
      branchId: branchId,
      operationId: operationId,
    );
  }

  static ConnectorConfig connectorConfig = ConnectorConfig(
    'asia-southeast1',
    'pos-connector',
    'jce-pos-service',
  );

  PosConnectorConnector({required this.dataConnect});
  static PosConnectorConnector get instance {
    return PosConnectorConnector(
      dataConnect: FirebaseDataConnect.instanceFor(
        connectorConfig: connectorConfig,
        sdkType: CallerSDKType.generated,
      ),
    );
  }

  FirebaseDataConnect dataConnect;
}
