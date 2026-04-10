import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../shared/widgets/shared_widgets.dart';
import 'package:intl/intl.dart';

class CommercialDesiredQuantity extends ConsumerWidget {
  const CommercialDesiredQuantity({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commercialAsync = ref.watch(currentCommercialProvider);

    return commercialAsync.when(
      loading: () => const AppLoading(),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (commercial) {
        if (commercial == null) return const SizedBox.shrink();
        final ordersAsync = ref.watch(commercialOrdersProvider(commercial.id));

        return ordersAsync.when(
          loading: () => const AppLoading(),
          error: (e, _) => Center(child: Text('Erreur: $e')),
          data: (orders) {
            final totalQte = orders.fold<double>(0, (s, o) => s + o.qteDemande + o.supplement);
            final totalLivre = orders.fold<double>(0, (s, o) => s + o.qteLivre);
            final remaining = totalQte - totalLivre;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary cards
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      StatCard(
                        label: 'Mes commandes',
                        value: '${orders.length}',
                        icon: Icons.receipt_long_outlined,
                        color: AppColors.accent,
                        animIndex: 0,
                      ),
                      StatCard(
                        label: 'Total demandé',
                        value: '${totalQte.toStringAsFixed(1)} ton',
                        icon: Icons.inventory_2_outlined,
                        color: AppColors.statusInProgress,
                        animIndex: 1,
                      ),
                      StatCard(
                        label: 'Total livré',
                        value: '${totalLivre.toStringAsFixed(1)} ton',
                        icon: Icons.local_shipping_outlined,
                        color: AppColors.statusDelivered,
                        animIndex: 2,
                      ),
                      StatCard(
                        label: 'Restant',
                        value: '${remaining.toStringAsFixed(1)} ton',
                        icon: Icons.hourglass_bottom_outlined,
                        color: AppColors.accentOrange,
                        animIndex: 3,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Détail par commande'),
                  const SizedBox(height: 12),
                  if (orders.isEmpty)
                    const EmptyState(message: 'Aucune commande en cours')
                  else
                    ...orders.map((o) => _OrderQuantityRow(order: o)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _OrderQuantityRow extends StatelessWidget {
  final OrderModel order;
  const _OrderQuantityRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final pct = order.qteDemande > 0
        ? (order.qteLivre / (order.qteDemande + order.supplement)).clamp(0.0, 1.0)
        : 0.0;
    final color = pct >= 1.0
        ? AppColors.statusDelivered
        : pct > 0.5
            ? AppColors.statusInProgress
            : AppColors.accent;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '#${order.orderId}',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    order.beton,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${order.qteLivre}/${order.qteDemande + order.supplement} ton',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: AppColors.divider,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              order.chantier,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
