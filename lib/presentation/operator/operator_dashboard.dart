import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../shared/widgets/shared_widgets.dart';
import '../shared/dialogs/order_detail_dialog.dart';

class OperatorDashboard extends ConsumerWidget {
  const OperatorDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(activeOrdersProvider);
    final clientsAsync = ref.watch(clientsProvider);
    final staffAsync = ref.watch(staffProvider);

    return ordersAsync.when(
      loading: () => const AppLoading(),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (orders) {
        final clients = clientsAsync.value ?? [];
        final staff = staffAsync.value ?? [];

        final totalQte = orders.fold<double>(0, (s, o) => s + o.qteDemande);
        final totalLivre = orders.fold<double>(0, (s, o) => s + o.qteLivre);

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vue d\'ensemble', style: Theme.of(context).textTheme.titleLarge)
                        .animate()
                        .fadeIn(duration: 400.ms),
                    const SizedBox(height: 4),
                    Text('${orders.length} commande(s) en cours', style: Theme.of(context).textTheme.bodyMedium)
                        .animate()
                        .fadeIn(delay: 100.ms, duration: 400.ms),
                    const SizedBox(height: 16),

                    // Stats
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Commandes',
                            value: '${orders.length}',
                            icon: Icons.pending_actions_outlined,
                            color: AppColors.operatorColor,
                            animIndex: 0,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            label: 'Total ton',
                            value: '${totalQte.toStringAsFixed(1)}',
                            icon: Icons.inventory_2_outlined,
                            color: AppColors.accent,
                            animIndex: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Livré',
                            value: '${totalLivre.toStringAsFixed(1)} ton',
                            icon: Icons.local_shipping_outlined,
                            color: AppColors.statusDelivered,
                            animIndex: 2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            label: 'Restant',
                            value: '${(totalQte - totalLivre).toStringAsFixed(1)} ton',
                            icon: Icons.hourglass_empty_outlined,
                            color: AppColors.accentLight,
                            animIndex: 3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Commandes en cours'),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            if (orders.isEmpty)
              const SliverFillRemaining(
                child: EmptyState(
                  message: 'Aucune commande en cours',
                  icon: Icons.inbox_outlined,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final o = orders[i];
                      final client = clients.firstWhere(
                        (c) => c.id == o.clientId,
                        orElse: () => _emptyClient(o.clientId),
                      );
                      final commercial = staff.firstWhere(
                        (s) => s.id == o.commercialId,
                        orElse: () => _emptyCommercial(o.commercialId),
                      );
                      return OrderCard(
                        order: o,
                        clientName: client.fullName,
                        commercialName: commercial.fullName,
                        onTap: () => showDialog(
                          context: ctx,
                          builder: (_) => OrderDetailDialog(order: o, clientName: client.fullName),
                        ),
                      );
                    },
                    childCount: orders.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  ClientModel _emptyClient(String id) => ClientModel(
        id: id, name: id, firstName: '', phone: '', company: '',
        address: '', managerName: '', contactName: '', contactPhone: '',
        plafond: 0, plafondDisponible: 0, plafondFake: 0,
        isBlocked: false, isDeleted: false, chantiers: [],
      );

  CommercialModel _emptyCommercial(String id) => CommercialModel(
        id: id, firstname: '', name: id, email: '', phone: '', address: '', role: '', password: ''
      );
}
