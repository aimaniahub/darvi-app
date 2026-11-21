import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:mini_pos_inventory/core/widgets/widgets.dart';

void main() {
  group('Global AppHeader Standardization Tests', () {
    testWidgets('AppHeader renders standard title and 64px height', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: const AppHeader(
              title: 'Dashboard',
            ),
            body: Container(),
          ),
        ),
      );

      expect(find.text('Dashboard'), findsOneWidget);
      final headerFinder = find.byType(AppHeader);
      expect(headerFinder, findsOneWidget);

      final AppHeader header = tester.widget(headerFinder);
      expect(header.preferredSize.height, equals(64.0));
      expect(header.preferredSize.width, equals(double.infinity));
    });

    testWidgets('AppHeader renders breadcrumb trail and subtitle properly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: const AppHeader(
              title: 'GA-101 Plot Details',
              breadcrumbs: ['Vikshha CRM', 'Projects'],
            ),
            body: Container(),
          ),
        ),
      );

      expect(find.text('Vikshha CRM'), findsOneWidget);
      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('GA-101 Plot Details'), findsOneWidget);
    });

    testWidgets('AppHeader displays back button when showBackButton is true', (tester) async {
      bool backPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppHeader(
              title: 'Invoice Details',
              showBackButton: true,
              onBackPressed: () => backPressed = true,
            ),
            body: Container(),
          ),
        ),
      );

      final backButton = find.byTooltip('Back');
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pumpAndSettle();
      expect(backPressed, isTrue);
    });

    testWidgets('AppHeader displays sidebar toggle when at root', (tester) async {
      bool sidebarToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppHeader(
              title: 'Products',
              showBackButton: false,
              showSidebarToggle: true,
              onSidebarToggle: () => sidebarToggled = true,
            ),
            body: Container(),
          ),
        ),
      );

      final menuButton = find.byTooltip('Menu & Sidebar');
      expect(menuButton, findsOneWidget);

      await tester.tap(menuButton);
      await tester.pumpAndSettle();
      expect(sidebarToggled, isTrue);
    });

    testWidgets('AppHeader renders actions cleanly without overflow', (tester) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppHeader(
              title: 'Stock Central',
              actions: [
                IconButton(
                  icon: const Icon(TablerIcons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () => actionTapped = true,
                ),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('New Entry'),
                ),
              ],
            ),
            body: Container(),
          ),
        ),
      );

      expect(find.byTooltip('Refresh'), findsOneWidget);
      expect(find.text('New Entry'), findsOneWidget);

      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(actionTapped, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AppHeader handles bottom TabBar with combined height', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: const AppHeader(
                title: 'Parties',
                bottom: TabBar(
                  tabs: [
                    Tab(text: 'Customers'),
                    Tab(text: 'Suppliers'),
                  ],
                ),
              ),
              body: const TabBarView(
                children: [
                  Text('Customers View'),
                  Text('Suppliers View'),
                ],
              ),
            ),
          ),
        ),
      );

      final headerFinder = find.byType(AppHeader);
      expect(headerFinder, findsOneWidget);
      final AppHeader header = tester.widget(headerFinder);
      expect(header.preferredSize.height, equals(64.0 + kTextTabBarHeight));
      expect(find.text('Customers'), findsOneWidget);
      expect(find.text('Suppliers'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

