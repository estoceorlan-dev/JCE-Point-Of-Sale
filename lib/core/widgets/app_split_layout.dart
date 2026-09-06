import 'package:flutter/material.dart';

import '../constants/app_breakpoints.dart';
import '../theme/app_spacing.dart';

/// Centers two sections on wide screens and stacks them on smaller screens.
class AppSplitLayout extends StatelessWidget {
  const AppSplitLayout({
    super.key,
    required this.content,
    required this.illustration,
  });

  final Widget content;
  final Widget illustration;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSplit = constraints.maxWidth >= AppBreakpoints.tablet;
        final padding = constraints.maxWidth < AppBreakpoints.compact
            ? AppSpacing.xl
            : AppSpacing.xxl;
        final form = Align(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: content,
          ),
        );

        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppBreakpoints.wide),
              child: isSplit
                  ? Row(
                      children: [
                        Expanded(flex: 5, child: form),
                        const SizedBox(width: AppSpacing.xl * 2),
                        Expanded(flex: 7, child: illustration),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        form,
                        const SizedBox(height: AppSpacing.xl * 2),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: illustration,
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
