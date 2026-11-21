import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/cards.dart';
import '../cubit/dashboard_state.dart';

class DashboardChartsSection extends StatelessWidget {
  const DashboardChartsSection({
    super.key,
    required this.state,
    required this.onPeriodChanged,
  });

  final DashboardState state;
  final ValueChanged<String> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 720;

        if (isTablet) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DarviSectionHeader(title: 'Analytics & Financial Visualizations'),
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: _buildSalesTrendCard(),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 4,
                    child: _buildPaymentBreakdownCard(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildTopProductsCard(),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _buildPlotStatusCard(),
                  ),
                ],
              ),
            ],
          );
        }

        // Mobile layout: stacked
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DarviSectionHeader(title: 'Analytics & Trends'),
            const SizedBox(height: AppSpacing.sm),
            _buildSalesTrendCard(),
            const SizedBox(height: AppSpacing.md),
            _buildPaymentBreakdownCard(),
            const SizedBox(height: AppSpacing.md),
            _buildTopProductsCard(),
            const SizedBox(height: AppSpacing.md),
            _buildPlotStatusCard(),
          ],
        );
      },
    );
  }

  Widget _buildSalesTrendCard() {
    final points = state.salesTrend;
    final maxRevenue = points.isEmpty ? 1000.0 : points.map((p) => p.revenue).reduce((a, b) => a > b ? a : b);
    final maxY = maxRevenue > 0 ? (maxRevenue * 1.25) : 1000.0;

    return DarviChartCard(
      title: 'Sales Revenue Trend',
      subtitle: 'Daily gross sales performance',
      filterOptions: const ['7D', '30D', 'Month'],
      selectedFilter: state.selectedPeriod,
      onFilterChanged: onPeriodChanged,
      child: SizedBox(
        height: 220,
        child: points.isEmpty
            ? const Center(child: Text('No sales recorded in this period', style: TextStyle(color: Colors.grey)))
            : BarChart(
                BarChartData(
                  maxY: maxY,
                  alignment: BarChartAlignment.spaceAround,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppColors.primaryDark,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final p = points[group.x.toInt()];
                        return BarTooltipItem(
                          '${p.label}\n${AppFormatters.money(p.revenue)}\n(${p.count} invoices)',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        getTitlesWidget: (val, meta) {
                          if (val == 0) return const SizedBox.shrink();
                          if (val >= 100000) {
                            return Text('${(val / 100000).toStringAsFixed(1)}L', style: const TextStyle(fontSize: 10, color: Colors.grey));
                          } else if (val >= 1000) {
                            return Text('${(val / 1000).toStringAsFixed(0)}k', style: const TextStyle(fontSize: 10, color: Colors.grey));
                          }
                          return Text(val.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey));
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx >= 0 && idx < points.length) {
                            // On 30-day view, show label every 5 days
                            if (points.length > 10 && idx % 4 != 0 && idx != points.length - 1) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(points[idx].label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => const FlLine(color: AppColors.border, strokeWidth: 1),
                  ),
                  barGroups: List.generate(points.length, (i) {
                    final p = points[i];
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: p.revenue,
                          color: AppColors.primary,
                          width: points.length > 15 ? 8 : 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }),
                ),
              ),
      ),
    );
  }

  Widget _buildPaymentBreakdownCard() {
    final map = state.paymentBreakdown;
    final total = map.values.fold(0.0, (sum, v) => sum + v);
    final cash = map['Cash'] ?? 0.0;
    final bank = map['Bank'] ?? 0.0;
    final upi = map['UPI'] ?? 0.0;

    return DarviChartCard(
      title: 'Payment Breakdown',
      subtitle: 'Distribution of collections',
      child: total == 0
          ? Container(
              height: 220,
              alignment: Alignment.center,
              child: const Text('No payments recorded this month', style: TextStyle(color: Colors.grey)),
            )
          : Column(
              children: [
                SizedBox(
                  height: 140,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 36,
                      sections: [
                        PieChartSectionData(
                          value: cash > 0 ? cash : 0.01,
                          title: '${total > 0 ? ((cash / total) * 100).toStringAsFixed(0) : 0}%',
                          color: AppColors.primary,
                          radius: 35,
                          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                        PieChartSectionData(
                          value: bank > 0 ? bank : 0.01,
                          title: '${total > 0 ? ((bank / total) * 100).toStringAsFixed(0) : 0}%',
                          color: Colors.blue.shade600,
                          radius: 35,
                          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                        PieChartSectionData(
                          value: upi > 0 ? upi : 0.01,
                          title: '${total > 0 ? ((upi / total) * 100).toStringAsFixed(0) : 0}%',
                          color: Colors.purple.shade600,
                          radius: 35,
                          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _legendItem(color: AppColors.primary, label: 'Cash', value: AppFormatters.money(cash)),
                    _legendItem(color: Colors.blue.shade600, label: 'Bank', value: AppFormatters.money(bank)),
                    _legendItem(color: Colors.purple.shade600, label: 'UPI', value: AppFormatters.money(upi)),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _legendItem({required Color color, required String label, required String value}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildTopProductsCard() {
    final products = state.topSellingProducts;

    return DarviChartCard(
      title: 'Top-Selling Products',
      subtitle: 'Ranked by monthly gross sales',
      child: SizedBox(
        height: 180,
        child: products.isEmpty
            ? const Center(child: Text('No item sales recorded this month', style: TextStyle(color: Colors.grey)))
            : ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p = products[i];
                  return Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i == 0 ? AppColors.warningContainer : AppColors.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: i == 0 ? AppColors.warning : AppColors.primaryDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['name'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                            ),
                            Text(
                              'Qty: ${p['qty']} units',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        AppFormatters.money(p['revenue'] as double),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.primary),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildPlotStatusCard() {
    final counts = state.plotStatusCounts;
    final total = counts.values.fold(0, (sum, v) => sum + v);
    final available = counts['Available'] ?? 0;
    final reserved = counts['Reserved'] ?? 0;
    final booked = counts['Booked'] ?? 0;
    final sold = counts['Sold'] ?? 0;

    return DarviChartCard(
      title: 'Vikshha Plot Availability',
      subtitle: 'Inventory status for Farmland plots',
      child: SizedBox(
        height: 180,
        child: total == 0
            ? const Center(child: Text('No plots registered yet', style: TextStyle(color: Colors.grey)))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _statusProgressRow(label: 'Available', count: available, total: total, color: AppColors.success),
                  const SizedBox(height: 8),
                  _statusProgressRow(label: 'Reserved', count: reserved, total: total, color: Colors.orange),
                  const SizedBox(height: 8),
                  _statusProgressRow(label: 'Booked', count: booked, total: total, color: Colors.amber.shade800),
                  const SizedBox(height: 8),
                  _statusProgressRow(label: 'Sold', count: sold, total: total, color: Colors.blueGrey),
                ],
              ),
      ),
    );
  }

  Widget _statusProgressRow({required String label, required int count, required int total, required Color color}) {
    final pct = total > 0 ? (count / total) : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 75,
          child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: AppRadii.sm,
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: AppColors.background,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 55,
          child: Text(
            '$count (${(pct * 100).toStringAsFixed(0)}%)',
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

