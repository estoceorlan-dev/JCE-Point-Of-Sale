import 'package:flutter/material.dart';

import '../../../../core/sync/pos_bootstrap_repository.dart';
import '../../../../core/theme/app_spacing.dart';

class PreparingTerminalPanel extends StatelessWidget {
  const PreparingTerminalPanel({
    super.key,
    required this.progress,
    required this.onRetry,
  });

  final PosBootstrapProgress progress;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failed = progress.status == PosBootstrapStatus.failed;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  failed ? Icons.cloud_off_outlined : Icons.point_of_sale,
                  size: 48,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  failed ? 'Terminal preparation paused' : 'Preparing terminal',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  failed
                      ? progress.message ??
                            'Connect to the internet, then retry. Existing local data was not changed.'
                      : 'Downloading the branch catalog and POS settings. Administration remains available.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (!failed) ...[
                  LinearProgressIndicator(value: progress.fraction),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${progress.completedCollections} of ${progress.totalCollections} sections',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry preparation'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
