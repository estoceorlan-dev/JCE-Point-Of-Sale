import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_breakpoints.dart';
import '../theme/app_spacing.dart';
import 'sidebar/sidebar_controller.dart';
import 'sidebar/sidebar_toggle.dart';

/// Slides navigation beside wide content and uses a modal drawer on compact
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
    VoidCallback close,
    bool isDesktop,
  )
  sidebarBuilder;
  final Widget Function(BuildContext context, Widget toggle, bool isDesktop)
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

            void close() {
              controller.close();
              _scaffoldKey.currentState?.closeDrawer();
            }

            void toggle() {
              controller.toggle();
              if (!isDesktop && ref.read(provider)) {
                _scaffoldKey.currentState?.openDrawer();
              }
            }

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
                child: widget.sidebarBuilder(context, close, isDesktop),
              ),
              onDrawerChanged: isDesktop ? null : controller.setExpanded,
              body: Row(
                children: [
                  _AnimatedSidebar(
                    expanded: isDesktop && expanded,
                    animate: isDesktop,
                    child: isDesktop
                        ? widget.sidebarBuilder(context, close, isDesktop)
                        : const SizedBox.shrink(),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        SafeArea(
                          bottom: false,
                          child: widget.headerBuilder(
                            context,
                            SidebarToggle(
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
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: expanded ? 1 : 0),
      duration: !animate || MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      child: ExcludeFocus(
        excluding: !expanded,
        child: ExcludeSemantics(
          excluding: !expanded,
          child: IgnorePointer(
            ignoring: !expanded,
            child: TickerMode(enabled: expanded, child: child),
          ),
        ),
      ),
      builder: (context, value, child) => SizedBox(
        width: AppSpacing.sidebarWidth * value,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerRight,
            minWidth: AppSpacing.sidebarWidth,
            maxWidth: AppSpacing.sidebarWidth,
            child: Opacity(opacity: value, child: child),
          ),
        ),
      ),
    );
  }
}
