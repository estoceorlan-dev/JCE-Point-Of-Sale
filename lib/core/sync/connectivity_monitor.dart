import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityMonitorProvider = Provider<ConnectivityMonitor>((ref) {
  return PluginConnectivityMonitor(Connectivity());
});

abstract interface class ConnectivityMonitor {
  Future<bool> get isConnected;
  Stream<bool> get changes;
}

class PluginConnectivityMonitor implements ConnectivityMonitor {
  PluginConnectivityMonitor(this._connectivity);

  final Connectivity _connectivity;

  @override
  Future<bool> get isConnected async =>
      _hasNetwork(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get changes =>
      _connectivity.onConnectivityChanged.map(_hasNetwork).distinct();

  bool _hasNetwork(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}
