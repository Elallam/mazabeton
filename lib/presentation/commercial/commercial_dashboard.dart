import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/models.dart';
import '../../data/repositories/firestore_repository.dart' show PlafondException;
import '../shared/widgets/shared_widgets.dart';
import '../shared/dialogs/order_detail_dialog.dart';

class CommercialDashboard extends ConsumerWidget {
  const CommercialDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(currentCommercialProvider).when(
      loading: () => const AppLoading(),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (commercial) {
        if (commercial == null) return const Center(child: Text('Profil introuvable'));
        return _DashboardBody(commercial: commercial);
      },
    );
  }
}

// ─── Helpers ───────────────────────────────────────────────────────────────────

bool _isDueToday(OrderModel order) {
  final d = order.deliveryDate;
  if (d == null) return false;
  final now = DateTime.now();
  return d.year == now.year && d.month == now.month && d.day == now.day;
}

// ─── Body ──────────────────────────────────────────────────────────────────────

class _DashboardBody extends ConsumerWidget {
  final CommercialModel commercial;
  const _DashboardBody({required this.commercial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(commercialOrdersProvider(commercial.id));
    final clients    = ref.watch(clientsProvider).value ?? [];
    final viewMode   = ref.watch(dashboardViewModeProvider);

    return ordersAsync.when(
      loading: () => const AppLoading(),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (orders) {
        final totalQte    = orders.fold<double>(0, (s, o) => s + o.qteDemande);
        final totalLivre  = orders.fold<double>(0, (s, o) => s + o.qteLivre);
        final totalSupplement = orders.fold<double>(0, (s, o) => s + o.supplement);
        final dueTodayCount = orders.where(_isDueToday).length;
        return Column(
          children: [
            // ── Header band ────────────────────────────────────────────
            _HeaderBand(
              commercial: commercial,
              orderCount: orders.length,
              totalQte: totalQte,
              totalLivre: totalLivre,
              totalSupplement: totalSupplement,
              viewMode: viewMode,
              dueTodayCount: dueTodayCount,
            ),

            // ── Content ────────────────────────────────────────────────
            Expanded(
              child: orders.isEmpty
                  ? const EmptyState(
                message: 'Aucune commande en cours.\nCréez votre première commande.',
                icon: Icons.receipt_long_outlined,
              )
                  : viewMode == DashboardViewMode.cards
                  ? _CardView(orders: orders, clients: clients, commercial: commercial)
                  : _TableView(orders: orders, clients: clients, commercial: commercial),
            ),
          ],
        );
      },
    );
  }
}

// ─── Header band ───────────────────────────────────────────────────────────────

class _HeaderBand extends ConsumerWidget {
  final CommercialModel commercial;
  final int orderCount;
  final double totalQte;
  final double totalLivre;
  final double totalSupplement;
  final DashboardViewMode viewMode;
  final int dueTodayCount;

  const _HeaderBand({
    required this.commercial,
    required this.orderCount,
    required this.totalQte,
    required this.totalLivre,
    required this.viewMode,
    required this.totalSupplement,
    required this.dueTodayCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.primaryLight,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bonjour, ${commercial.firstname}',
                        style: Theme.of(context).textTheme.titleMedium)
                        .animate()
                        .fadeIn(duration: 400.ms),
                    Text('$orderCount commande(s) en cours',
                        style: Theme.of(context).textTheme.bodyMedium)
                        .animate()
                        .fadeIn(delay: 80.ms, duration: 400.ms),
                  ],
                ),
              ),
              // ── Toggle button ──────────────────────────────────────
              _ViewToggle(current: viewMode),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Demandé',
                  value: '${totalQte.toStringAsFixed(1)} ton',
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: 'Livré',
                  value: '${totalLivre.toStringAsFixed(1)} ton',
                  color: AppColors.statusDelivered,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: 'Restant',
                  value: '${(totalQte - totalLivre).toStringAsFixed(1)} ton',
                  color: AppColors.accentLight,
                ),
              ),
            ],
          ),
          // ── Due-today alert banner ─────────────────────────────────
          if (dueTodayCount > 0) ...[
            const SizedBox(height: 10),
            _DueTodayBanner(count: dueTodayCount),
          ],
        ],
      ),
    );
  }
}

// ─── Due-today animated banner ─────────────────────────────────────────────────

class _DueTodayBanner extends StatefulWidget {
  final int count;
  const _DueTodayBanner({required this.count});

  @override
  State<_DueTodayBanner> createState() => _DueTodayBannerState();
}

class _DueTodayBannerState extends State<_DueTodayBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const warningColor = Color(0xFFE65100); // deep orange
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFF6D00).withOpacity(0.13 + 0.07 * _pulse.value),
              const Color(0xFFFF3D00).withOpacity(0.07 + 0.05 * _pulse.value),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: warningColor.withOpacity(0.35 + 0.25 * _pulse.value),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: warningColor.withOpacity(0.12 * _pulse.value),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Pulsing icon
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: warningColor.withOpacity(0.15 + 0.1 * _pulse.value),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.access_time_filled_rounded,
                color: warningColor.withOpacity(0.7 + 0.3 * _pulse.value),
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${widget.count} livraison${widget.count > 1 ? 's' : ''} ',
                      style: const TextStyle(
                        color: warningColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const TextSpan(
                      text: 'prévue${0 > 1 ? 's' : ''} aujourd\'hui',
                      style: TextStyle(
                        color: warningColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: warningColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: warningColor.withOpacity(0.3), width: 1),
              ),
              child: Text(
                'Urgent',
                style: TextStyle(
                  color: warningColor.withOpacity(0.9),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: -0.2, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }
}

// ─── Toggle button ─────────────────────────────────────────────────────────────

class _ViewToggle extends ConsumerWidget {
  final DashboardViewMode current;
  const _ViewToggle({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleBtn(
            icon: Icons.view_agenda_outlined,
            selected: current == DashboardViewMode.cards,
            tooltip: 'Vue cartes',
            onTap: () => ref
                .read(dashboardViewModeProvider.notifier)
                .state = DashboardViewMode.cards,
          ),
          Container(width: 1, height: 20, color: AppColors.divider),
          _ToggleBtn(
            icon: Icons.table_rows_outlined,
            selected: current == DashboardViewMode.table,
            tooltip: 'Vue tableau',
            onTap: () => ref
                .read(dashboardViewModeProvider.notifier)
                .state = DashboardViewMode.table,
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  const _ToggleBtn({
    required this.icon,
    required this.selected,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 18,
            color: selected ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Card view (original) ──────────────────────────────────────────────────────

class _CardView extends ConsumerWidget {
  final List<OrderModel> orders;
  final List<ClientModel> clients;
  final CommercialModel commercial;

  const _CardView({
    required this.orders,
    required this.clients,
    required this.commercial,
  });

  ClientModel _client(String id) => clients.firstWhere(
        (c) => c.id == id,
    orElse: () => ClientModel(
        id: id, name: id, firstName: '', phone: '', company: '',
        address: '', managerName: '', contactName: '', contactPhone: '',
        plafond: 0, plafondDisponible: 0, plafondFake: 0,
        isBlocked: false, isDeleted: false, chantiers: []),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: orders.length,
      itemBuilder: (ctx, i) {
        final order = orders[i];
        final dueToday = _isDueToday(order);
        final card = OrderCard(
          order: order,
          clientName: _client(order.clientId).fullName,
          trailing: IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.accent, size: 20),
            onPressed: () => _showUpdateSheet(ctx, ref, order),
          ),
          onTap: () => showDialog(
            context: ctx,
            builder: (_) => OrderDetailDialog(
              order: order,
              clientName: _client(order.clientId).fullName,
            ),
          ),
        );
        if (!dueToday) return card;
        return _DueTodayCardWrapper(child: card);
      },
    );
  }

  void _showUpdateSheet(BuildContext context, WidgetRef ref, OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _UpdateOrderSheet(order: order, commercial: commercial),
    );
  }
}

// ─── Due-today card wrapper ────────────────────────────────────────────────────

class _DueTodayCardWrapper extends StatefulWidget {
  final Widget child;
  const _DueTodayCardWrapper({required this.child});

  @override
  State<_DueTodayCardWrapper> createState() => _DueTodayCardWrapperState();
}

class _DueTodayCardWrapperState extends State<_DueTodayCardWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const warningColor = Color(0xFFE65100);
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, child) => Stack(
        children: [
          // Glowing border container
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: warningColor.withOpacity(0.3 + 0.35 * _glow.value),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: warningColor.withOpacity(0.08 + 0.10 * _glow.value),
                  blurRadius: 10 + 4 * _glow.value,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: child,
          ),
          // "Aujourd'hui" badge in top-right corner
          Positioned(
            top: 0,
            right: 12,
            child: Transform.translate(
              offset: const Offset(0, -9),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF6D00),
                      const Color(0xFFFF3D00).withOpacity(0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: warningColor.withOpacity(0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.schedule_rounded,
                        size: 10, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Livraison aujourd\'hui',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      child: widget.child,
    );
  }
}

// ─── Table view ────────────────────────────────────────────────────────────────

class _TableView extends ConsumerStatefulWidget {
  final List<OrderModel> orders;
  final List<ClientModel> clients;
  final CommercialModel commercial;

  const _TableView({
    required this.orders,
    required this.clients,
    required this.commercial,
  });

  @override
  ConsumerState<_TableView> createState() => _TableViewState();
}

class _TableViewState extends ConsumerState<_TableView> {
  // Sort state
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  // Column definitions: (header label, flex, value extractor for sorting)
  static const _columns = [
    ('Client', 2),
    ('Chantier', 2),
    ('Béton', 2),
    ('Qté dem.', 1),
    ('Qté livrée', 1),
    ('Statut', 1),
    ('Date', 2),
    ('', 1), // actions
  ];

  ClientModel _client(String id) => widget.clients.firstWhere(
        (c) => c.id == id,
    orElse: () => ClientModel(
        id: id, name: id, firstName: '', phone: '', company: '',
        address: '', managerName: '', contactName: '', contactPhone: '',
        plafond: 0, plafondDisponible: 0, plafondFake: 0,
        isBlocked: false, isDeleted: false, chantiers: []),
  );

  List<OrderModel> get _sorted {
    final list = List<OrderModel>.from(widget.orders);
    list.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0: cmp = _client(a.clientId).fullName.compareTo(_client(b.clientId).fullName); break;
        case 1: cmp = a.chantier.compareTo(b.chantier); break;
        case 2: cmp = a.beton.compareTo(b.beton); break;
        case 3: cmp = a.qteDemande.compareTo(b.qteDemande); break;
        case 4: cmp = a.qteLivre.compareTo(b.qteLivre); break;
        case 5: cmp = a.status.compareTo(b.status); break;
        case 6: cmp = a.createdAt.compareTo(b.createdAt); break;
        default: cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
    return list;
  }

  void _onSort(int col) {
    setState(() {
      if (_sortColumnIndex == col) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = col;
        _sortAscending = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = _sorted;
    final fmt = DateFormat('dd/MM/yy');

    return Column(
      children: [
        // ── Header row ──────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Container(
              color: AppColors.card,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              child: Row(
                children: _columns.asMap().entries.map((e) {
                  final idx = e.key;
                  final label = e.value.$1;
                  final flex = e.value.$2;
                  final isAction = idx == _columns.length - 1;

                  return Expanded(
                    flex: flex,
                    child: isAction
                        ? const SizedBox.shrink()
                        : _HeaderCell(
                      label: label,
                      sorted: _sortColumnIndex == idx,
                      ascending: _sortAscending,
                      onTap: label.isNotEmpty ? () => _onSort(idx) : null,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1),

        // ── Data rows ───────────────────────────────────────────────
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: rows.length,
            separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AppColors.divider),
            itemBuilder: (ctx, i) {
              final order = rows[i];
              final clientName = _client(order.clientId).fullName;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: _TableRow(
                    order: order,
                    clientName: clientName,
                    index: i,
                    onEdit: () => _showUpdateSheet(ctx, order),
                    onTap: () => _showDetailSheet(ctx, order, clientName),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showUpdateSheet(BuildContext context, OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _UpdateOrderSheet(order: order, commercial: widget.commercial),
    );
  }

  void _showDetailSheet(BuildContext context, OrderModel order, String clientName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _OrderDetailSheet(order: order, clientName: clientName),
    );
  }
}

// ─── Order detail sheet (table view tap) ──────────────────────────────────────

class _OrderDetailSheet extends StatelessWidget {
  final OrderModel order;
  final String clientName;

  const _OrderDetailSheet({
    required this.order,
    required this.clientName,
  });

  Color get _statusColor {
    switch (order.status) {
      case AppConstants.statusPending:    return AppColors.statusPending;
      case AppConstants.statusInProgress: return AppColors.statusInProgress;
      case AppConstants.statusDelivered:  return AppColors.statusDelivered;
      case AppConstants.statusCanceled:   return AppColors.statusCanceled;
      default: return AppColors.textMuted;
    }
  }

  String get _statusLabel {
    switch (order.status) {
      case AppConstants.statusPending:    return 'En attente';
      case AppConstants.statusInProgress: return 'En cours';
      case AppConstants.statusDelivered:  return 'Livré';
      case AppConstants.statusCanceled:   return 'Annulé';
      default: return order.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt     = DateFormat('dd/MM/yyyy HH:mm');
    final fmtDate = DateFormat('dd/MM/yyyy');
    final remaining = order.qteDemande - order.qteLivre;
    final progress = order.qteDemande > 0
        ? (order.qteLivre / order.qteDemande).clamp(0.0, 1.0)
        : 0.0;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Column(
          children: [
            // ── Handle + header (sticky) ────────────────────────────
            Container(
              decoration: const BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Order ID + status badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#${order.orderId}',
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _statusColor.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _statusColor.withOpacity(0.4)),
                        ),
                        child: Text(
                          _statusLabel,
                          style: TextStyle(
                            color: _statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Paid badge
                      if (order.soldPaid == order.qteDemande*order.betonPrice)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.statusDelivered.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.check_circle_outline,
                                  size: 12, color: AppColors.statusDelivered),
                              SizedBox(width: 4),
                              Text('Payé',
                                  style: TextStyle(
                                      color: AppColors.statusDelivered,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.beton,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),

            // ── Scrollable content ──────────────────────────────────
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [

                  // ── Delivery progress ─────────────────────────────
                  _DetailSection(
                    title: 'Livraison',
                    icon: Icons.local_shipping_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _InfoTile(
                                label: 'Demandé',
                                value: '${order.qteDemande.toStringAsFixed(2)} t',
                                valueColor: AppColors.accent,
                              ),
                            ),
                            Expanded(
                              child: _InfoTile(
                                label: 'Livré',
                                value: '${order.qteLivre.toStringAsFixed(2)} t',
                                valueColor: AppColors.statusDelivered,
                              ),
                            ),
                            Expanded(
                              child: _InfoTile(
                                label: 'Restant',
                                value: '${remaining.toStringAsFixed(2)} t',
                                valueColor: remaining > 0
                                    ? AppColors.accentLight
                                    : AppColors.statusDelivered,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: AppColors.divider,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress >= 1.0
                                  ? AppColors.statusDelivered
                                  : AppColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}% livré',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 11),
                        ),
                        if (order.supplement > 0) ...[
                          const SizedBox(height: 10),
                          _InfoTile(
                            label: 'Supplément',
                            value: '+ ${order.supplement.toStringAsFixed(2)} t',
                            valueColor: AppColors.accentLight,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Client & chantier ─────────────────────────────
                  _DetailSection(
                    title: 'Client & Chantier',
                    icon: Icons.business_outlined,
                    child: Column(
                      children: [
                        _InfoRow(label: 'Client', value: clientName),
                        _InfoRow(label: 'Chantier', value: order.chantier),
                        _InfoRow(label: 'Contact', value: order.contact),
                        _InfoRow(label: 'Tél. contact', value: order.contactPhone, isPhone: true,),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Béton & prix ──────────────────────────────────
                  _DetailSection(
                    title: 'Béton & Prix',
                    icon: Icons.inventory_2_outlined,
                    child: Column(
                      children: [
                        _InfoRow(label: 'Type béton', value: order.beton),
                        _InfoRow(label: 'ID béton', value: order.betonId),
                        _InfoRow(
                          label: 'Prix unitaire',
                          value: '${order.betonPrice.toStringAsFixed(2)} MAD/t',
                        ),
                        _InfoRow(
                          label: 'Total estimé',
                          value: '${(order.betonPrice * order.qteDemande).toStringAsFixed(2)} MAD',
                          highlight: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Dates ─────────────────────────────────────────
                  _DetailSection(
                    title: 'Dates',
                    icon: Icons.calendar_today_outlined,
                    child: Column(
                      children: [
                        _InfoRow(
                          label: 'Créée le',
                          value: fmt.format(order.createdAt),
                        ),
                        if (order.deliveryDate != null)
                          _InfoRow(
                            label: 'Livraison prévue',
                            value: fmtDate.format(order.deliveryDate!),
                            valueColor: AppColors.accentLight,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── IDs ───────────────────────────────────────────
                  _DetailSection(
                    title: 'Références',
                    icon: Icons.tag_outlined,
                    child: Column(
                      children: [
                        _InfoRow(label: 'ID commande', value: order.id),
                        _InfoRow(label: 'N° commande', value: order.orderId),
                        _InfoRow(label: 'ID client', value: order.clientId),
                        _InfoRow(label: 'ID commercial', value: order.commercialId),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Detail sheet sub-widgets ──────────────────────────────────────────────────

class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _DetailSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool highlight;
  final bool isPhone;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.highlight = false,
    this.isPhone = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          isPhone ? Expanded(
            child: GestureDetector(
              onTap: value.isEmpty ? () => callPhone(value) : null,
              child: _InfoChip(icon: Icons.phone_outlined, label: value, tappable: value.isNotEmpty),
            ),
          ) : Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ??
                    (highlight ? AppColors.accent : AppColors.textPrimary),
                fontSize: 12,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoTile({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 10)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

// ─── Table header cell ─────────────────────────────────────────────────────────

class _HeaderCell extends StatelessWidget {
  final String label;
  final bool sorted;
  final bool ascending;
  final VoidCallback? onTap;

  const _HeaderCell({
    required this.label,
    required this.sorted,
    required this.ascending,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: sorted ? AppColors.accent : AppColors.textSecondary,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (sorted) ...[
              const SizedBox(width: 2),
              Icon(
                ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 10,
                color: AppColors.accent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Table data row ────────────────────────────────────────────────────────────

class _TableRow extends StatelessWidget {
  final OrderModel order;
  final String clientName;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onTap;

  const _TableRow({
    required this.order,
    required this.clientName,
    required this.index,
    required this.onEdit,
    required this.onTap,
  });

  Color get _statusColor {
    switch (order.status) {
      case AppConstants.statusPending:    return AppColors.statusPending;
      case AppConstants.statusInProgress: return AppColors.statusInProgress;
      case AppConstants.statusDelivered:  return AppColors.statusDelivered;
      case AppConstants.statusCanceled:   return AppColors.statusCanceled;
      default: return AppColors.textMuted;
    }
  }

  String get _statusLabel {
    switch (order.status) {
      case AppConstants.statusPending:    return 'Attente';
      case AppConstants.statusInProgress: return 'En cours';
      case AppConstants.statusDelivered:  return 'Livré';
      case AppConstants.statusCanceled:   return 'Annulé';
      default: return order.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yy');
    final isEven = index % 2 == 0;
    final dueToday = _isDueToday(order);
    const warningColor = Color(0xFFE65100);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: dueToday
              ? warningColor.withOpacity(0.06)
              : (isEven
              ? AppColors.primary
              : AppColors.primaryLight.withOpacity(0.4)),
          border: dueToday
              ? Border(
            left: BorderSide(color: warningColor, width: 3),
          )
              : null,
        ),
        padding: EdgeInsets.only(
          left: dueToday ? 5 : 8,
          right: 8,
          top: 10,
          bottom: 10,
        ),
        child: Row(
          children: [
            // Client
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  if (dueToday)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.access_time_filled_rounded,
                          size: 12, color: warningColor),
                    ),
                  Expanded(child: _Cell(clientName,
                      color: dueToday ? warningColor : null)),
                ],
              ),
            ),
            // Chantier
            Expanded(
              flex: 2,
              child: _Cell(order.chantier),
            ),
            // Béton
            Expanded(
              flex: 2,
              child: _Cell(order.beton),
            ),
            // Qté dem
            Expanded(
              flex: 1,
              child: _Cell('${order.qteDemande.toStringAsFixed(1)}'),
            ),
            // Qté livrée
            Expanded(
              flex: 1,
              child: _Cell(
                '${order.qteLivre.toStringAsFixed(1)}',
                color: order.qteLivre >= order.qteDemande
                    ? AppColors.statusDelivered
                    : null,
              ),
            ),
            // Statut
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(
                      color: _statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Date
            Expanded(
              flex: 2,
              child: dueToday
                  ? Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 3),
                decoration: BoxDecoration(
                  color: warningColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                      color: warningColor.withOpacity(0.3), width: 0.8),
                ),
                child: Text(
                  fmt.format(order.deliveryDate!),
                  style: const TextStyle(
                    color: warningColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              )
                  : _Cell(order.deliveryDate != null
                  ? fmt.format(order.deliveryDate!)
                  : fmt.format(order.createdAt)),
            ),
            // Actions
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.edit_outlined,
                        size: 14, color: AppColors.accent),
                  ),
                ),
              ),
            ),
          ],
        ),
      )
          .animate(delay: Duration(milliseconds: 20 * index))
          .fadeIn(duration: 250.ms),
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final Color? color;
  const _Cell(this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 12,
            color: color ?? AppColors.textSecondary),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
    );
  }
}

// ─── Mini stat chip ────────────────────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}

// ─── Update order bottom sheet (shared by both views) ──────────────────────────

class _UpdateOrderSheet extends ConsumerStatefulWidget {
  final OrderModel order;
  final CommercialModel commercial;

  const _UpdateOrderSheet({required this.order, required this.commercial});

  @override
  ConsumerState<_UpdateOrderSheet> createState() => _UpdateOrderSheetState();
}

class _UpdateOrderSheetState extends ConsumerState<_UpdateOrderSheet> {
  late TextEditingController _qteCtrl;
  late TextEditingController _suppCtrl;
  late String _status;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _qteCtrl  = TextEditingController(text: widget.order.qteLivre.toString());
    _suppCtrl = TextEditingController(text: widget.order.supplement.toString());
    _status   = widget.order.status;
  }

  @override
  void dispose() {
    _qteCtrl.dispose();
    _suppCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {

      await ref.read(firestoreRepoProvider).updateOrder(
        widget.order.id,
        {
          'qteLivre':   double.tryParse(_qteCtrl.text)  ?? widget.order.qteLivre,
          'supplement': double.tryParse(_suppCtrl.text) ?? widget.order.supplement,
          'status':     _status,
        },
        widget.order,
        widget.commercial.id,
        widget.commercial.fullName,
      );

      if (mounted) Navigator.pop(context);
    } on PlafondException catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.card,
            title: const Row(children: [
              Icon(Icons.block, color: AppColors.error, size: 20),
              SizedBox(width: 10),
              Flexible(child: Text('Plafond dépassé')),
            ]),
            content: Text(e.message,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 18),

          // Order ID + béton
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('#${widget.order.orderId}',
                  style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.8)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.order.beton,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 20),

          // Status chips
          const Text('Statut',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppConstants.statusPending,
              AppConstants.statusInProgress,
              AppConstants.statusDelivered,
              AppConstants.statusCanceled,
            ].map((s) {
              final sel = _status == s;
              final color = _sColor(s);
              return GestureDetector(
                onTap: () => setState(() => _status = s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? color.withOpacity(0.18) : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: sel ? color : AppColors.divider,
                        width: sel ? 1.5 : 1),
                  ),
                  child: Text(_sLabel(s),
                      style: TextStyle(
                          color: sel ? color : AppColors.textSecondary,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 13)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Qty fields
          Row(children: [
            Expanded(
              child: _SheetField(
                ctrl: _qteCtrl,
                label: 'Qté livrée (ton)',
                icon: Icons.local_shipping_outlined,
                maxValue: widget.order.qteDemande + widget.order.supplement,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _SheetField(
                ctrl: _suppCtrl,
                label: 'Supplément (ton)',
                icon: Icons.add_circle_outline,
              ),
            ),
          ]),
          const SizedBox(height: 26),

          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
                  : const Text('ENREGISTRER',
                  style: TextStyle(letterSpacing: 1.2)),
            ),
          ),
        ],
      ),
    );
  }

  Color _sColor(String s) {
    switch (s) {
      case AppConstants.statusPending:    return AppColors.statusPending;
      case AppConstants.statusInProgress: return AppColors.statusInProgress;
      case AppConstants.statusDelivered:  return AppColors.statusDelivered;
      case AppConstants.statusCanceled:   return AppColors.statusCanceled;
      default: return AppColors.textMuted;
    }
  }

  String _sLabel(String s) {
    switch (s) {
      case AppConstants.statusPending:    return 'En attente';
      case AppConstants.statusInProgress: return 'En cours';
      case AppConstants.statusDelivered:  return 'Livré';
      case AppConstants.statusCanceled:   return 'Annulé';
      default: return s;
    }
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final double? maxValue;


  const _SheetField({required this.ctrl, required this.label, required this.icon, this.maxValue});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(

          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18),
            isDense: true,
          ),

          inputFormatters: [
            // Add the max value validator
            if (maxValue != null)
              TextInputFormatter.withFunction((oldValue, newValue) {
                if (newValue.text.isEmpty) return newValue;

                // Try to parse the input as a number
                final double? value = double.tryParse(newValue.text);

                // If it's a valid number and exceeds maxValue, reject the change
                if (value != null && value > maxValue!) {
                  return oldValue; // Reject the change
                }

                return newValue; // Accept the change
              }),
          ],
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool tappable;
  const _InfoChip({required this.icon, required this.label, this.tappable = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tappable
            ? AppColors.statusDelivered.withOpacity(0.08)
            : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
        border: tappable
            ? Border.all(color: AppColors.statusDelivered.withOpacity(0.25))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13,
              color: tappable ? AppColors.statusDelivered : AppColors.textMuted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: tappable ? AppColors.statusDelivered : AppColors.textSecondary,
                    decoration: tappable ? TextDecoration.underline : null,
                    decorationColor: AppColors.statusDelivered),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}