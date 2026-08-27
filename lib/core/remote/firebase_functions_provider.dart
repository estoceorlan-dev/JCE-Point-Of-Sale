import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

final firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) {
  final region = ref.watch(appConfigProvider).firebaseFunctionsRegion;
  return region == null
      ? FirebaseFunctions.instance
      : FirebaseFunctions.instanceFor(region: region);
});
