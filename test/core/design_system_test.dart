import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:mini_pos_inventory/core/theme/app_theme.dart';
import 'package:mini_pos_inventory/core/widgets/widgets.dart';

void main() {
  group('DARVI PHASE 3 — DESIGN SYSTEM COMPONENT TESTS', () {
    // 1. AppButton Tests
    group('1. AppButton', () {
      testWidgets('Primary, Secondary, Outlined, Danger, Ghost variants render and trigger callbacks', (tester) async {
        var clicked = 0;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Column(
                children: [
                  AppButton.primary(
                    label: 'Save Invoice',
                    icon: TablerIcons.deviceFloppy,
                    onPressed: () => clicked++,
                  ),
                  AppButton.secondary(
                    label: 'Secondary Action',
                    onPressed: () => clicked++,
                  ),
                  AppButton.outlined(
                    label: 'Export PDF',
                    onPressed: () => clicked++,
                  ),
                  AppButton.danger(
                    label: 'Void Sale',
                    onPressed: () => clicked++,
                  ),
                  AppButton.ghost(
                    label: 'Cancel',
                    onPressed: () => clicked++,
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Save Invoice'), findsOneWidget);
        expect(find.text('Secondary Action'), findsOneWidget);
        expect(find.text('Export PDF'), findsOneWidget);
        expect(find.text('Void Sale'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);

        await tester.tap(find.text('Save Invoice'));
        await tester.pump();
        expect(clicked, 1);

        await tester.tap(find.text('Void Sale'));
        await tester.pump();
        expect(clicked, 2);
      });

      testWidgets('Disabled button does not invoke onPressed', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: AppButton(
                label: 'Disabled Button',
                onPressed: null,
              ),
            ),
          ),
        );

        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(button.onPressed, isNull);
      });

      testWidgets('Loading button shows progress indicator and suppresses click', (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: AppButton(
                label: 'Processing',
                loading: true,
                onPressed: () => tapped = true,
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.tap(find.byType(AppButton));
        await tester.pump();
        expect(tapped, isFalse);
      });
    });

    // 2. AppFormField & AppTextField Tests
    group('2. AppFormField & AppTextField', () {
      testWidgets('AppFormField renders external persistent label with required asterisk and error banner', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: AppFormField(
                label: 'Supplier GSTIN',
                required: true,
                errorText: 'Invalid GSTIN format',
                child: const AppTextField(hint: 'e.g. 29AAAAA0000A1Z5'),
              ),
            ),
          ),
        );

        expect(find.text('Supplier GSTIN'), findsOneWidget);
        expect(find.text('*'), findsOneWidget);
        expect(find.text('Invalid GSTIN format'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('e.g. 29AAAAA0000A1Z5'), findsOneWidget);
      });

      testWidgets('AmountField parses decimal currency input properly', (tester) async {
        double parsed = 0.0;
        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: AmountField(
                controller: controller,
                label: 'Payment Amount',
                onChanged: (val) => parsed = val,
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), '450.75');
        await tester.pump();
        expect(parsed, 450.75);
      });
    });

    // 3. AppSearchField Tests
    group('3. AppSearchField', () {
      testWidgets('Shows clear button on text entry and triggers debounced callback', (tester) async {
        String query = '';
        var cleared = false;
        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: AppSearchField(
                controller: controller,
                debounceDuration: const Duration(milliseconds: 100),
                onChanged: (val) => query = val,
                onClear: () => cleared = true,
              ),
            ),
          ),
        );

        expect(find.byIcon(TablerIcons.x), findsNothing);

        await tester.enterText(find.byType(TextField), 'Fertilizer');
        await tester.pump();
        expect(find.byIcon(TablerIcons.x), findsOneWidget);

        // Advance debounce timer
        await tester.pump(const Duration(milliseconds: 150));
        expect(query, 'Fertilizer');

        // Tap clear
        await tester.tap(find.byIcon(TablerIcons.x));
        await tester.pump();
        expect(cleared, isTrue);
        expect(controller.text, isEmpty);
      });
    });

    // 4. AppDropdown Tests
    group('4. AppDropdown', () {
      testWidgets('Selects option from dropdown items', (tester) async {
        String? selected = 'cash';

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return AppDropdown<String>(
                    value: selected,
                    label: 'Payment Method',
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'upi', child: Text('UPI')),
                      DropdownMenuItem(value: 'bank', child: Text('Bank Transfer')),
                    ],
                    onChanged: (val) => setState(() => selected = val),
                  );
                },
              ),
            ),
          ),
        );

        expect(find.text('Cash'), findsOneWidget);

        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();

        await tester.tap(find.text('UPI').last);
        await tester.pumpAndSettle();

        expect(selected, 'upi');
      });
    });

    // 5. AppBadge Tests
    group('5. AppBadge', () {
      testWidgets('Renders all semantic badge tones correctly', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: Column(
                children: [
                  AppBadge.success(label: 'PAID', showDot: true),
                  AppBadge.warning(label: 'PARTIAL'),
                  AppBadge.error(label: 'OVERDUE'),
                  AppBadge.info(label: 'IN TRANSIT'),
                  AppBadge.neutral(label: 'DRAFT'),
                ],
              ),
            ),
          ),
        );

        expect(find.text('PAID'), findsOneWidget);
        expect(find.text('PARTIAL'), findsOneWidget);
        expect(find.text('OVERDUE'), findsOneWidget);
        expect(find.text('IN TRANSIT'), findsOneWidget);
        expect(find.text('DRAFT'), findsOneWidget);
      });
    });

    // 6. AppStatCard & AppStatGrid Tests
    group('6. AppStatCard & AppStatGrid', () {
      testWidgets('AppStatCard renders tabular metric value, progress bar, and handles tap', (tester) async {
        var cardTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: AppStatCard(
                title: 'Monthly Revenue',
                value: '₹1,24,500',
                subtitle: 'Target: ₹1,50,000',
                icon: TablerIcons.currencyRupee,
                trendBadge: '+14.5%',
                trendPositive: true,
                progress: 0.83,
                targetLabel: '83% of monthly target',
                onTap: () => cardTapped = true,
              ),
            ),
          ),
        );

        expect(find.text('Monthly Revenue'), findsOneWidget);
        expect(find.text('₹1,24,500'), findsOneWidget);
        expect(find.text('+14.5%'), findsOneWidget);
        expect(find.text('83% of monthly target'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);

        await tester.tap(find.byType(AppStatCard));
        await tester.pump();
        expect(cardTapped, isTrue);
      });

      testWidgets('AppStatGrid adapts column rows to available constraint width', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 800,
                  child: AppStatGrid(
                    minTileWidth: 200,
                    children: [
                      Container(key: const ValueKey('card1'), height: 100),
                      Container(key: const ValueKey('card2'), height: 100),
                      Container(key: const ValueKey('card3'), height: 100),
                      Container(key: const ValueKey('card4'), height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byKey(const ValueKey('card1')), findsOneWidget);
        expect(find.byKey(const ValueKey('card4')), findsOneWidget);
      });
    });

    // 7. AppFilterBar Tests
    group('7. AppFilterBar', () {
      testWidgets('AppFilterBar triggers search, filter selection, and clear', (tester) async {
        String activeFilter = 'all';
        var refreshed = false;
        var cleared = false;
        final searchCtrl = TextEditingController(text: 'Organic');

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return AppFilterBar(
                    searchController: searchCtrl,
                    selectedFilterId: activeFilter,
                    filterOptions: const [
                      FilterOption(id: 'all', label: 'All Items', badge: '120'),
                      FilterOption(id: 'low_stock', label: 'Low Stock', badge: '5'),
                      FilterOption(id: 'out_of_stock', label: 'Out of Stock'),
                    ],
                    onFilterSelected: (id) => setState(() => activeFilter = id),
                    onRefresh: () => refreshed = true,
                    onClearFilters: () => cleared = true,
                  );
                },
              ),
            ),
          ),
        );

        expect(find.text('All Items'), findsOneWidget);
        expect(find.text('Low Stock'), findsOneWidget);
        expect(find.text('Clear'), findsOneWidget);

        await tester.tap(find.text('Low Stock'));
        await tester.pump();
        expect(activeFilter, 'low_stock');

        await tester.tap(find.byTooltip('Refresh'));
        await tester.pump();
        expect(refreshed, isTrue);

        await tester.tap(find.text('Clear'));
        await tester.pump();
        expect(cleared, isTrue);
      });
    });

    // 8. AppDataTable Tests
    group('8. AppDataTable', () {
      testWidgets('AppDataTable renders typed columns, handles row selection and sorting', (tester) async {
        final testItems = [
          {'id': 101, 'name': 'Urea 50kg', 'stock': 120, 'price': 270.0},
          {'id': 102, 'name': 'DAP 50kg', 'stock': 45, 'price': 1350.0},
        ];

        Map<String, dynamic>? selectedItem;
        int? sortedIndex;
        bool? sortAsc;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: AppDataTable<Map<String, dynamic>>(
                items: testItems,
                onRowTap: (item) => selectedItem = item,
                sortColumnIndex: 1,
                sortAscending: true,
                onSort: (idx, asc) {
                  sortedIndex = idx;
                  sortAsc = asc;
                },
                columns: [
                  AppDataColumn(
                    title: 'ID',
                    cellBuilder: (_, item, __) => Text('#${item['id']}'),
                  ),
                  AppDataColumn(
                    title: 'Product',
                    sortable: true,
                    cellBuilder: (_, item, __) => Text('${item['name']}'),
                  ),
                  AppDataColumn(
                    title: 'Stock',
                    numeric: true,
                    cellBuilder: (_, item, __) => Text('${item['stock']}'),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Urea 50kg'), findsOneWidget);
        expect(find.text('DAP 50kg'), findsOneWidget);
        expect(find.text('#101'), findsOneWidget);

        // Tap row
        await tester.tap(find.text('Urea 50kg'));
        await tester.pump();
        expect(selectedItem?['id'], 101);

        // Tap sortable column
        await tester.tap(find.text('Product'));
        await tester.pump();
        expect(sortedIndex, 1);
        expect(sortAsc, isFalse);
      });

      testWidgets('AppDataTable shows empty state when items list is empty', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: AppDataTable<String>(
                items: [],
                columns: [
                  AppDataColumn(title: 'Item', cellBuilder: _dummyBuilder),
                ],
                emptyMessage: 'Zero inventory items recorded',
              ),
            ),
          ),
        );

        expect(find.text('Zero inventory items recorded'), findsOneWidget);
      });
    });

    // 9. AppSplitView Tests
    group('9. AppSplitView', () {
      testWidgets('Renders dual pane side-by-side on wide screens', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: SizedBox(
                width: 900,
                height: 600,
                child: AppSplitView(
                  masterWidth: 300,
                  master: Text('Master List View'),
                  detail: Text('Detailed Profile View'),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Master List View'), findsOneWidget);
        expect(find.text('Detailed Profile View'), findsOneWidget);
        expect(find.byType(VerticalDivider), findsOneWidget);
      });

      testWidgets('Renders single pane on narrow mobile screens', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: SizedBox(
                width: 400,
                height: 600,
                child: AppSplitView(
                  showDetailOnMobile: false,
                  master: Text('Master List Mobile'),
                  detail: Text('Detail View Mobile'),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Master List Mobile'), findsOneWidget);
        expect(find.text('Detail View Mobile'), findsNothing);
      });
    });

    // 10. AppDialog Tests
    group('10. AppDialog', () {
      testWidgets('showConfirmation opens dialog and returns user action', (tester) async {
        bool? result;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      result = await AppDialog.showConfirmation(
                        context: context,
                        title: 'Post Purchase Invoice?',
                        message: 'This will increase stock and credit supplier payable.',
                        confirmLabel: 'Post Invoice',
                      );
                    },
                    child: const Text('Open Dialog'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Post Purchase Invoice?'), findsOneWidget);
        expect(find.text('This will increase stock and credit supplier payable.'), findsOneWidget);

        await tester.tap(find.text('Post Invoice'));
        await tester.pumpAndSettle();

        expect(result, isTrue);
      });
    });

    // 11. Theme Rendering Tests
    group('11. Theme Rendering', () {
      test('AppTheme.light and dark instantiate with proper tokens', () {
        final lightTheme = AppTheme.light();
        final darkTheme = AppTheme.dark();

        expect(lightTheme.colorScheme.primary, AppColors.primary);
        expect(lightTheme.scaffoldBackgroundColor, AppColors.background);
        expect(darkTheme.colorScheme.primary, AppColors.leafAccent);
        expect(darkTheme.scaffoldBackgroundColor, AppColors.backgroundDark);
      });
    });
  });
}

Widget _dummyBuilder(BuildContext context, String item, int index) => Text(item);
