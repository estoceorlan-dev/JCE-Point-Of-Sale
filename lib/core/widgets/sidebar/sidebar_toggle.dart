import 'package:flutter/material.dart';

import '../../theme/app_radii.dart';

class SidebarToggle extends StatelessWidget {
  const SidebarToggle({
    super.key,
    required this.expanded,
    required this.onPressed,
    this.collapseToRail = false,
  });

  final bool expanded;
  final VoidCallback onPressed;
  final bool collapseToRail;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: collapseToRail
          ? (expanded ? 'Collapse sidebar' : 'Expand sidebar')
          : (expanded ? 'Close sidebar' : 'Open sidebar'),
      onPressed: onPressed,
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      icon: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        child: Icon(
          expanded ? Icons.menu_open_rounded : Icons.view_sidebar_outlined,
          key: ValueKey(expanded),
        ),
      ),
    );
  }
}
