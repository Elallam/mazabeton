import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../shared/widgets/shared_widgets.dart';

class DesiredQuantityScreen extends ConsumerWidget {
  const DesiredQuantityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderBetonsAsync = ref.watch(orderBetonsProvider);
    final activeOrdersAsync = ref.watch(activeOrdersProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary stats
            activeOrdersAsync.when(
              loading: () => const AppLoading(),
              error: (_, __) => const SizedBox.shrink(),
              data: (orders) {
                final totalQte = orders.fold<double>(0, (s, o) => s + o.qteDemande);
                final totalLivre = orders.fold<double>(0, (s, o) => s + o.qteLivre);
                return GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    StatCard(
                      label: 'Total demandé',
                      value: '${totalQte.toStringAsFixed(1)} ton',
                      icon: Icons.inventory_2_outlined,
                      color: AppColors.accent,
                      animIndex: 0,
                    ),
                    StatCard(
                      label: 'Total livré',
                      value: '${totalLivre.toStringAsFixed(1)} ton',
                      icon: Icons.local_shipping_outlined,
                      color: AppColors.statusDelivered,
                      animIndex: 1,
                    ),
                    StatCard(
                      label: 'Commandes actives',
                      value: '${orders.length}',
                      icon: Icons.pending_actions_outlined,
                      color: AppColors.statusInProgress,
                      animIndex: 2,
                    ),
                    StatCard(
                      label: 'Reste à livrer',
                      value: '${(totalQte - totalLivre).toStringAsFixed(1)} ton',
                      icon: Icons.hourglass_empty_outlined,
                      color: AppColors.accentOrange,
                      animIndex: 3,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Chart
            const SectionHeader(title: 'Quantités demandées (historique)'),
            const SizedBox(height: 16),
            orderBetonsAsync.when(
              loading: () => const AppLoading(),
              error: (_, __) => const SizedBox.shrink(),
              data: (betons) {
                if (betons.isEmpty) {
                  return const EmptyState(message: 'Aucune donnée de quantité disponible');
                }
                return _QuantityChart(betons: betons.take(10).toList());
              },
            ),
            const SizedBox(height: 24),

            // List
            const SectionHeader(title: 'Historique des quantités'),
            const SizedBox(height: 12),
            orderBetonsAsync.when(
              loading: () => const AppLoading(),
              error: (_, __) => const SizedBox.shrink(),
              data: (betons) => Column(
                children: betons.map((b) => _QuantityRow(item: b)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityChart extends StatelessWidget {
  final List<OrderBetonModel> betons;
  const _QuantityChart({required this.betons});

  @override
  Widget build(BuildContext context) {
    final spots = betons.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.qte);
    }).toList();

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: AppColors.divider,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) => Text(
                  '${v.toInt()}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                ),
                reservedSize: 32,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= betons.length) return const SizedBox.shrink();
                  return Text(
                    DateFormat('dd/MM').format(betons[idx].createDate),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
                  );
                },
                reservedSize: 24,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.accent,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.accent.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityRow extends StatelessWidget {
  final OrderBetonModel item;
  const _QuantityRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: AppColors.accent),
          const SizedBox(width: 12),
          Text(
            DateFormat('dd/MM/yyyy HH:mm').format(item.createDate),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${item.qte} ton',
              style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
