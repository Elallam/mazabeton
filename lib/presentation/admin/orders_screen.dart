import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../shared/widgets/shared_widgets.dart';
import '../shared/dialogs/order_detail_dialog.dart';

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter  = ref.watch(orderFilterProvider);
    final clients = ref.watch(clientsProvider).value ?? [];
    final staff   = ref.watch(staffProvider).value ?? [];
    final betons  = ref.watch(betonsProvider).value ?? [];

    // Chantiers available for the selected client
    final selectedClient = filter.clientName == null
        ? null
        : clients.firstWhere((c) => c.id == filter.clientName,
        orElse: () => ClientModel(
            id: '', name: '', firstName: '', phone: '', company: '',
            address: '', managerName: '', contactName: '', contactPhone: '',
            plafond: 0, plafondDisponible: 0, plafondFake: 0,
            isBlocked: false, isDeleted: false, chantiers: []));

    return Column(
      children: [
        // ── Filter band ─────────────────────────────────────────────────
        Container(
          color: AppColors.primaryLight,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Rechercher commandes...',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const SizedBox(height: 8),

              // Row 1: client / commercial / dates
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _Chip(
                      label: 'Client',
                      value: selectedClient?.fullName,
                      icon: Icons.person_outline,
                      onTap: () => _pickClient(clients),
                      onClear: filter.clientName != null
                          ? () => ref.read(orderFilterProvider.notifier).update(
                        filter.copyWith(
                          clearClient: true,
                          clearChantier: true,
                          clearBeton: true,
                        ),
                      )
                          : null,
                    ),
                    const SizedBox(width: 6),
                    _Chip(
                      label: 'Commercial',
                      value: filter.commercialName == null
                          ? null
                          : staff
                          .firstWhere((s) => s.id == filter.commercialName,
                          orElse: () => CommercialModel(
                              id: '', firstname: '', name: filter.commercialName!,
                              email: '', phone: '', address: '', role: '', password: ''))
                          .fullName,
                      icon: Icons.badge_outlined,
                      onTap: () => _pickCommercial(staff),
                      onClear: filter.commercialName != null
                          ? () => ref.read(orderFilterProvider.notifier).update(
                          filter.copyWith(clearCommercial: true))
                          : null,
                    ),
                    const SizedBox(width: 6),
                    _Chip(
                      label: 'Début',
                      value: filter.startDate != null
                          ? DateFormat('dd/MM/yy').format(filter.startDate!)
                          : null,
                      icon: Icons.calendar_today_outlined,
                      onTap: () => _pickDate(isStart: true),
                      onClear: filter.startDate != null
                          ? () => ref.read(orderFilterProvider.notifier).update(
                          filter.copyWith(clearStartDate: true))
                          : null,
                    ),
                    const SizedBox(width: 6),
                    _Chip(
                      label: 'Fin',
                      value: filter.endDate != null
                          ? DateFormat('dd/MM/yy').format(filter.endDate!)
                          : null,
                      icon: Icons.event_outlined,
                      onTap: () => _pickDate(isStart: false),
                      onClear: filter.endDate != null
                          ? () => ref.read(orderFilterProvider.notifier).update(
                          filter.copyWith(clearEndDate: true))
                          : null,
                    ),
                    if (!filter.isEmpty) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () =>
                            ref.read(orderFilterProvider.notifier).reset(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.error.withOpacity(0.4)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.clear, size: 13, color: AppColors.error),
                              SizedBox(width: 4),
                              Text('Tout effacer',
                                  style: TextStyle(
                                      color: AppColors.error, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Row 2: chantier + béton chips (only when client selected)
              if (selectedClient != null &&
                  (selectedClient.chantiers.isNotEmpty || betons.isNotEmpty)) ...[
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Chantier chips
                      if (selectedClient.chantiers.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Text('Chantier:',
                              style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500)),
                        ),
                        ...selectedClient.chantiers.map((ch) {
                          final active = filter.chantier == ch;
                          return Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: GestureDetector(
                              onTap: () {
                                ref.read(orderFilterProvider.notifier).update(
                                  active
                                      ? filter.copyWith(clearChantier: true)
                                      : filter.copyWith(chantier: ch),
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.accentOrange.withOpacity(0.18)
                                      : AppColors.card,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: active
                                        ? AppColors.accentOrange
                                        : AppColors.divider,
                                    width: active ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  ch,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: active
                                        ? AppColors.accentOrange
                                        : AppColors.textSecondary,
                                    fontWeight: active
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],

                      // Béton type chips
                      if (betons.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Text('Béton:',
                              style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500)),
                        ),
                        ...betons.map((b) {
                          final active = filter.betonType == b.name;
                          return Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: GestureDetector(
                              onTap: () {
                                ref.read(orderFilterProvider.notifier).update(
                                  active
                                      ? filter.copyWith(clearBeton: true)
                                      : filter.copyWith(betonType: b.name),
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.accent.withOpacity(0.18)
                                      : AppColors.card,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: active
                                        ? AppColors.accent
                                        : AppColors.divider,
                                    width: active ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  b.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: active
                                        ? AppColors.accent
                                        : AppColors.textSecondary,
                                    fontWeight: active
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Tabs ────────────────────────────────────────────────────────
        Container(
          color: AppColors.primaryLight,
          child: TabBar(
            controller: _tabController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            tabs: const [
              Tab(text: 'En cours'),
              Tab(text: 'Terminées'),
            ],
          ),
        ),

        // ── Tab content ─────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _OrderList(
                ordersAsync: ref.watch(activeOrdersProvider),
                clients: clients,
                staff: staff,
                searchQuery: _searchQuery,
                filter: filter,
              ),
              _OrderList(
                ordersAsync: ref.watch(finishedOrdersProvider),
                clients: clients,
                staff: staff,
                searchQuery: _searchQuery,
                filter: filter,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Pickers ──────────────────────────────────────────────────────────────

  void _pickClient(List<ClientModel> clients) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scroll) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            const Text('Filtrer par client',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                controller: scroll,
                children: clients.map((c) => ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.accent.withOpacity(0.15),
                    child: Text(c.firstName.isNotEmpty ? c.firstName[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  title: Text(c.fullName, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(c.company, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  onTap: () {
                    ref.read(orderFilterProvider.notifier).update(
                      ref.read(orderFilterProvider).copyWith(
                          clientName: c.id,
                          clearChantier: true,
                          clearBeton: true),
                    );
                    Navigator.pop(context);
                  },
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickCommercial(List<CommercialModel> staff) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          const Text('Filtrer par commercial',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          ...staff.where((s) => s.role == 'commercial').map((s) => ListTile(
            title: Text(s.fullName),
            onTap: () {
              ref.read(orderFilterProvider.notifier).update(
                ref.read(orderFilterProvider).copyWith(commercialName: s.id),
              );
              Navigator.pop(context);
            },
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark()
            .copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.accent)),
        child: child!,
      ),
    );
    if (picked != null) {
      final f = ref.read(orderFilterProvider);
      ref.read(orderFilterProvider.notifier).update(
        isStart ? f.copyWith(startDate: picked) : f.copyWith(endDate: picked),
      );
    }
  }
}

// ── Order list ──────────────────────────────────────────────────────────────────

class _OrderList extends StatelessWidget {
  final AsyncValue<List<OrderModel>> ordersAsync;
  final List<ClientModel> clients;
  final List<CommercialModel> staff;
  final String searchQuery;
  final OrderFilter filter;

  const _OrderList({
    required this.ordersAsync,
    required this.clients,
    required this.staff,
    required this.searchQuery,
    required this.filter,
  });

  ClientModel _emptyClient(String id) => ClientModel(
      id: id, name: id, firstName: '', phone: '', company: '',
      address: '', managerName: '', contactName: '', contactPhone: '',
      plafond: 0, plafondDisponible: 0, plafondFake: 0,
      isBlocked: false, isDeleted: false, chantiers: []);

  CommercialModel _emptyStaff(String id) => CommercialModel(
      id: id, firstname: '', name: id, email: '', phone: '', address: '', role: '', password: '');

  List<OrderModel> _apply(List<OrderModel> orders) {
    return orders.where((o) {
      final client = clients.firstWhere((c) => c.id == o.clientId,
          orElse: () => _emptyClient(o.clientId));
      final commercial = staff.firstWhere((s) => s.id == o.commercialId,
          orElse: () => _emptyStaff(o.commercialId));

      if (searchQuery.isNotEmpty) {
        final match = client.fullName.toLowerCase().contains(searchQuery) ||
            o.chantier.toLowerCase().contains(searchQuery) ||
            o.beton.toLowerCase().contains(searchQuery) ||
            commercial.fullName.toLowerCase().contains(searchQuery);
        if (!match) return false;
      }
      if (filter.clientName != null && o.clientId != filter.clientName) return false;
      if (filter.chantier != null && o.chantier != filter.chantier) return false;
      if (filter.betonType != null && o.beton != filter.betonType) return false;
      if (filter.commercialName != null && o.commercialId != filter.commercialName) return false;
      if (filter.startDate != null && o.createdAt.isBefore(filter.startDate!)) return false;
      if (filter.endDate != null &&
          o.createdAt.isAfter(filter.endDate!.add(const Duration(days: 1)))) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ordersAsync.when(
      loading: () => const AppLoading(),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (orders) {
        final filtered = _apply(orders);
        if (filtered.isEmpty) {
          return const EmptyState(
              message: 'Aucune commande trouvée', icon: Icons.inbox_outlined);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: filtered.length,
          itemBuilder: (ctx, i) {
            final o = filtered[i];
            final client = clients.firstWhere((c) => c.id == o.clientId,
                orElse: () => _emptyClient(o.clientId));
            final commercial = staff.firstWhere((s) => s.id == o.commercialId,
                orElse: () => _emptyStaff(o.commercialId));
            return OrderCard(
              order: o,
              clientName: client.fullName,
              commercialName: commercial.fullName,
              onTap: () => showDialog(
                context: ctx,
                builder: (_) =>
                    OrderDetailDialog(order: o, clientName: client.fullName),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Filter chip with optional ✕ ────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _Chip({
    required this.label,
    this.value,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final active = value != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 160),
        padding: EdgeInsets.only(
            left: 10,
            top: 6,
            bottom: 6,
            right: active && onClear != null ? 4 : 10),
        decoration: BoxDecoration(
          color: active ? AppColors.accent.withOpacity(0.14) : AppColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active
                  ? AppColors.accent.withOpacity(0.5)
                  : AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: active ? AppColors.accent : AppColors.textSecondary),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                value ?? label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: active ? AppColors.accent : AppColors.textSecondary,
                  fontWeight:
                  active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (active && onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close,
                    size: 13, color: AppColors.accent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
