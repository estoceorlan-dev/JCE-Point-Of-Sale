import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/database/database_provider.dart';
import '../../../auth/presentation/providers/native_auth_providers.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../data/repositories/local_product_image_repository.dart';
import '../../domain/repositories/product_image_repository.dart';

final productImageRepositoryProvider = Provider<ProductImageRepository>((ref) {
  return LocalProductImageRepository(
    ref.watch(appDatabaseProvider),
    sessions: ref.watch(appConfigProvider).useNodeBackend
        ? ref.watch(nativeApiSessionRepositoryProvider)
        : null,
  );
});

final productImageBytesProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>((ref, productId) async {
      final context = ref.watch(businessContextProvider);
      if (context == null) return null;
      final result = await ref
          .watch(productImageRepositoryProvider)
          .load(context, productId);
      return result.valueOrNull;
    });
