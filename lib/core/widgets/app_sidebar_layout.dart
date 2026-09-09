import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_breakpoints.dart';
import '../theme/app_spacing.dart';
import 'sidebar/sidebar_controller.dart';
import 'sidebar/sidebar_toggle.dart';

/// Resizes navigation to an icon rail and uses a modal drawer on compact
/// screens. The body stays in the same tree position when the window resizes.
class AppSidebarLayout extends ConsumerStatefulWidget {
  const AppSidebarLayout({
    super.key,
    required this.sidebarBuilder,
    required this.headerBuilder,
    required this.body,
    this.bottomNavigationBar,
  });

  final Widget Function(
    BuildContext context,
    VoidCallback toggle,
    bool isDesktop,
    bool collapsed,
  )
  sidebarBuilder;
  final Widget Function(BuildContext context, Widget? toggle, bool isDesktop)
  headerBuilder;
  final Widget body;
  final Widget? bottomNavigationBar;

  @override
  ConsumerState<AppSidebarLayout> createState() => _AppSidebarLayoutState();
}

class _AppSidebarLayoutState extends ConsumerState<AppSidebarLayout> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool? _isDesktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop =
            constraints.maxWidth >= AppBreakpoints.desktopNavigation;
        if (_isDesktop != isDesktop) {
          _isDesktop = isDesktop;
          if (isDesktop) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _isDesktop == true) {
                _scaffoldKey.currentState?.closeDrawer();
              }
            });
          }
        }

        return Consumer(
          builder: (context, ref, child) {
            final provider = sidebarControllerProvider(isDesktop);
            final expanded = ref.watch(provider);
            final controller = ref.read(provider.notifier);
            ref.listen(provider, (_, isExpanded) {
              if (!isDesktop && !isExpanded) {
                _scaffoldKey.currentState?.closeDrawer();
              }
            });

            void toggle() {
              controller.toggle();
              if (!isDesktop && ref.read(provider)) {
                _scaffoldKey.currentState?.openDrawer();
              }
            }

            Widget sidebar(bool collapsed) => Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => controller.registerInteraction(),
              onPointerSignal: (_) => controller.registerInteraction(),
              child: widget.sidebarBuilder(
                context,
                toggle,
                isDesktop,
                collapsed,
              ),
            );

            return Scaffold(
              key: _scaffoldKey,
              // Keep the drawer mounted while crossing the breakpoint so its
              // closing animation can clear Scaffold's internal open state.
              drawerEnableOpenDragGesture: !isDesktop,
              drawer: Drawer(
                width: math.min(
                  AppSpacing.sidebarWidth,
                  math.max(
                    0,
                    constraints.maxWidth - AppSpacing.xxl - AppSpacing.lg,
                  ),
                ),
                child: sidebar(false),
              ),
              onDrawerChanged: isDesktop ? null : controller.setExpanded,
              body: Row(
                children: [
                  _AnimatedSidebar(
                    expanded: isDesktop && expanded,
                    animate: isDesktop,
                    child: isDesktop
                        ? sidebar(!expanded)
                        : const SizedBox.shrink(),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        SafeArea(
                          bottom: false,
                          child: widget.headerBuilder(
                            context,
                            isDesktop
                                ? null
                                : SidebarToggle(
                                    expanded: expanded,
                                    onPressed: toggle,
                                  ),
                            isDesktop,
                          ),
                        ),
                        Expanded(child: widget.body),
                      ],
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: isDesktop
                  ? null
                  : widget.bottomNavigationBar,
            );
          },
        );
      },
    );
  }
}

class _AnimatedSidebar extends StatelessWidget {
  const _AnimatedSidebar({
    required this.expanded,
    required this.animate,
    required this.child,
  });

  final bool expanded;
  final bool animate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      width: !animate
          ? 0
          : expanded
          ? AppSpacing.sidebarWidth
          : AppSpacing.collapsedSidebarWidth,
      duration: !animate || MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) => OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: AppSpacing.collapsedSidebarWidth,
          maxWidth: math.max(
            AppSpacing.collapsedSidebarWidth,
            constraints.maxWidth,
          ),
          child: child,
        ),
      ),
    );
  }
}
