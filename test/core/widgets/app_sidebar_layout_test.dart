import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/routing/app_navigation_item.dart';
import 'package:jce_pos/core/routing/app_route.dart';
import 'package:jce_pos/core/theme/app_spacing.dart';
import 'package:jce_pos/core/theme/app_theme.dart';
import 'package:jce_pos/core/widgets/app_sidebar_layout.dart';
import 'package:jce_pos/core/widgets/desktop_sidebar.dart';
import 'package:jce_pos/core/widgets/shell_top_bar.dart';
import 'package:jce_pos/core/widgets/sidebar/sidebar_toggle.dart';
import 'package:jce_pos/features/auth/data/repositories/hardcoded_auth_repository.dart';
import 'package:jce_pos/features/auth/domain/entities/auth_session.dart';

void main() {
  late AuthSession session;

  setUpAll(() async {
    final repository = HardcodedAuthRepository(branchId: 'sidebar-test');
    final result = await repository.signInWithEmailAndPassword(
      email: 'admin@jce.test',
      password: 'password123',
    );
    session = result.valueOrNull!;
    await repository.dispose();
  });

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
    bool reduceMotion = false,
    bool dark = false,
    ValueChanged<AppNavigationItem>? onDestinationSelected,
    VoidCallback? onSettingsSelected,
    VoidCallback? onLogout,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
          home: AppSidebarLayout(
            sidebarBuilder: (context, toggle, isDesktop, collapsed) =>
                DesktopSidebar(
                  items: navigationItemsForSession(session),
                  selectedRoute: AppRoute.dashboard,
                  session: session,
                  onToggle: toggle,
                  collapseToRail: isDesktop,
                  collapsed: collapsed,
                  onDestinationSelected: (item) {
                    onDestinationSelected?.call(item);
                    if (!isDesktop) toggle();
                  },
                  onSettingsSelected: onSettingsSelected ?? toggle,
                  onBranchSelected: (_, _) {},
                  onLogout: onLogout ?? toggle,
                ),
            headerBuilder: (context, toggle, isDesktop) => ShellTopBar(
              title: 'Registers & Hardware',
              session: session,
              sidebarToggle: toggle,
              isDesktop: isDesktop,
              onBranchSelected: (_, _) {},
              onRefreshAccess: () {},
              syncState: null,
              onSync: () {},
            ),
            body: const SizedBox.expand(
              key: ValueKey('page-body'),
              child: Align(alignment: Alignment.topLeft, child: TextField()),
            ),
            bottomNavigationBar: const SizedBox(
              height: 64,
              child: Text('Mobile navigation'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  double bodyLeft(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(const ValueKey('page-body'))).dx;

  testWidgets('desktop animates, releases width, and preserves page state', (
    tester,
  ) async {
    await mount(tester);
    await tester.pumpAndSettle();
    expect(bodyLeft(tester), AppSpacing.sidebarWidth);
    expect(find.byType(SidebarToggle), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DesktopSidebar),
        matching: find.byType(SidebarToggle),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ShellTopBar),
        matching: find.byType(SidebarToggle),
      ),
      findsNothing,
    );
    await tester.enterText(find.byType(TextField), 'Unsaved sale');

    await tester.tap(find.byTooltip('Collapse sidebar').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(bodyLeft(tester), greaterThan(AppSpacing.collapsedSidebarWidth));
    expect(bodyLeft(tester), lessThan(AppSpacing.sidebarWidth));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(bodyLeft(tester), AppSpacing.collapsedSidebarWidth);
    expect(find.text('Unsaved sale'), findsOneWidget);
    expect(find.text('Logout').hitTestable(), findsNothing);
    expect(find.byType(SidebarToggle), findsOneWidget);
    expect(find.byTooltip('POS').hitTestable(), findsOneWidget);
    expect(find.byTooltip('Settings').hitTestable(), findsOneWidget);
    expect(find.byTooltip('Logout').hitTestable(), findsOneWidget);

    await tester.tap(find.byTooltip('Expand sidebar'));
    await tester.pumpAndSettle();
    expect(bodyLeft(tester), AppSpacing.sidebarWidth);
    expect(find.text('Unsaved sale'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('collapsed icons navigate and retain account actions', (
    tester,
  ) async {
    AppRoute? destination;
    var settingsTapped = false;
    var logoutTapped = false;
    await mount(
      tester,
      onDestinationSelected: (item) => destination = item.route,
      onSettingsSelected: () => settingsTapped = true,
      onLogout: () => logoutTapped = true,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Collapse sidebar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('POS'));
    expect(destination, AppRoute.pos);
    expect(bodyLeft(tester), AppSpacing.collapsedSidebarWidth);
    await tester.tap(find.byTooltip('Settings'));
    await tester.tap(find.byTooltip('Logout'));
    expect(settingsTapped, isTrue);
    expect(logoutTapped, isTrue);
    expect(
      find.image(const AssetImage('assets/images/jce_logo.jpg')),
      findsOneWidget,
    );
    expect(find.byType(CircleAvatar), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(DesktopSidebar),
        matching: find.byTooltip('Switch branch'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate((widget) => widget is PopupMenuItem),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('auto-collapses 10 seconds after the last sidebar interaction', (
    tester,
  ) async {
    await mount(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 9));
    expect(bodyLeft(tester), AppSpacing.sidebarWidth);
    await tester.tap(find.text('POS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 9999));
    expect(bodyLeft(tester), AppSpacing.sidebarWidth);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(bodyLeft(tester), AppSpacing.collapsedSidebarWidth);
    await unmount(tester);
  });

  testWidgets('manual close cancels the old countdown', (tester) async {
    await mount(tester);
    await tester.pump(const Duration(seconds: 6));
    await tester.tap(find.byTooltip('Collapse sidebar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Expand sidebar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(bodyLeft(tester), AppSpacing.sidebarWidth);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(bodyLeft(tester), AppSpacing.collapsedSidebarWidth);
    await unmount(tester);
  });

  for (final size in [
    const Size(320, 568),
    const Size(800, 360),
    const Size(1023, 768),
  ]) {
    testWidgets(
      'compact drawer fits $size and closes after selection or timeout',
      (tester) async {
        await mount(tester, size: size, dark: true);
        await tester.pumpAndSettle();
        expect(bodyLeft(tester), 0);
        expect(find.text('Mobile navigation'), findsOneWidget);
        final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
        expect(scaffold.isDrawerOpen, isFalse);

        await tester.tap(find.byTooltip('Open sidebar'));
        await tester.pumpAndSettle();
        expect(scaffold.isDrawerOpen, isTrue);
        expect(bodyLeft(tester), 0);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('POS'));
        await tester.pumpAndSettle();
        expect(scaffold.isDrawerOpen, isFalse);

        await tester.tap(find.byTooltip('Open sidebar'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 10));
        await tester.pumpAndSettle();
        expect(scaffold.isDrawerOpen, isFalse);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      },
    );
  }

  testWidgets(
    'drawer dismissal stays in sync and timer does not pop branch menu',
    (tester) async {
      await mount(tester, size: const Size(390, 844));
      await tester.pumpAndSettle();
      final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
      await tester.tap(find.byTooltip('Open sidebar'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(370, 400));
      await tester.pumpAndSettle();
      expect(scaffold.isDrawerOpen, isFalse);
      expect(find.byTooltip('Open sidebar'), findsOneWidget);

      await tester.tap(find.byTooltip('Open sidebar'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(DesktopSidebar),
          matching: find.byTooltip('Switch branch'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(scaffold.isDrawerOpen, isFalse);
      expect(
        find.byWidgetPredicate((widget) => widget is PopupMenuItem),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
  );

  testWidgets(
    'resizing with a drawer open preserves content and allows reopening',
    (tester) async {
      await mount(tester);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Keep this draft');
      final original = tester.state(find.byType(TextField));
      tester.view.physicalSize = const Size(320, 568);
      await tester.pump();
      expect(bodyLeft(tester), 0);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(TextField)), same(original));

      await tester.tap(find.byTooltip('Open sidebar'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpAndSettle();
      expect(bodyLeft(tester), AppSpacing.sidebarWidth);
      expect(
        tester.state<ScaffoldState>(find.byType(Scaffold)).isDrawerOpen,
        isFalse,
      );
      expect(tester.state(find.byType(TextField)), same(original));
      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpAndSettle();
      expect(
        tester.state<ScaffoldState>(find.byType(Scaffold)).isDrawerOpen,
        isFalse,
      );
      await tester.tap(find.byTooltip('Open sidebar'));
      await tester.pumpAndSettle();
      expect(
        tester.state<ScaffoldState>(find.byType(Scaffold)).isDrawerOpen,
        isTrue,
      );
      expect(find.text('Keep this draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
  );

  testWidgets(
    'reduced motion collapses immediately and disposal cancels timer',
    (tester) async {
      await mount(tester, reduceMotion: true);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Collapse sidebar').first);
      await tester.pump();
      expect(bodyLeft(tester), AppSpacing.collapsedSidebarWidth);
      await tester.tap(find.byTooltip('Expand sidebar'));
      await tester.pump();
      expect(bodyLeft(tester), AppSpacing.sidebarWidth);
      await unmount(tester);
      await tester.pump(const Duration(seconds: 11));
      expect(tester.takeException(), isNull);
    },
  );
}
