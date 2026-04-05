import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../shared/widgets/shared_widgets.dart';
import 'package:intl/intl.dart';

class OperatorDesiredQuantity extends ConsumerWidget {
  const OperatorDesiredQuantity({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderBetonsAsync = ref.watch(orderBetonsProvider);
    final activeOrdersAsync = ref.watch(activeOrdersProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overview stats
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
                    color: AppColors.operatorColor,
                    animIndex: 0,
                  ),
                  StatCard(
                    label: 'Total livré',
                    value: '${totalLivre.toStringAsFixed(1)} ton',
                    icon: Icons.local_shipping_outlined,
                    color: AppColors.statusDelivered,
                    animIndex: 1,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Historique des quantités'),
          const SizedBox(height: 12),
          orderBetonsAsync.when(
            loading: () => const AppLoading(),
            error: (e, _) => Center(child: Text('Erreur: $e')),
            data: (betons) {
              if (betons.isEmpty) {
                return const EmptyState(
                  message: 'Aucune donnée de quantité',
                  icon: Icons.bar_chart_outlined,
                );
              }
              return Column(
                children: betons.map((b) {
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
                        const Icon(Icons.circle, size: 8, color: AppColors.operatorColor),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(b.createDate),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.operatorColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${b.qte} ton',
                            style: const TextStyle(
                              color: AppColors.operatorColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
