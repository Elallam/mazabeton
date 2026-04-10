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

        return Column(
          children: [
            // ── Header band ────────────────────────────────────────────
            _HeaderBand(
              commercial: commercial,
              orderCount: orders.length,
              totalQte: totalQte,
              totalLivre: totalLivre,
              viewMode: viewMode,
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
  final DashboardViewMode viewMode;

  const _HeaderBand({
    required this.commercial,
    required this.orderCount,
    required this.totalQte,
    required this.totalLivre,
    required this.viewMode,
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
                  color: AppColors.accentOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
        return OrderCard(
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
    ('N° Cmd', 1),
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
        case 0: cmp = a.orderId.compareTo(b.orderId); break;
        case 1: cmp = _client(a.clientId).fullName.compareTo(_client(b.clientId).fullName); break;
        case 2: cmp = a.chantier.compareTo(b.chantier); break;
        case 3: cmp = a.beton.compareTo(b.beton); break;
        case 4: cmp = a.qteDemande.compareTo(b.qteDemande); break;
        case 5: cmp = a.qteLivre.compareTo(b.qteLivre); break;
        case 6: cmp = a.status.compareTo(b.status); break;
        case 7: cmp = a.createdAt.compareTo(b.createdAt); break;
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
        Container(
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
              return _TableRow(
                order: order,
                clientName: clientName,
                index: i,
                onEdit: () => _showUpdateSheet(ctx, order),
                onTap: () => showDialog(
                  context: ctx,
                  builder: (_) => OrderDetailDialog(
                    order: order,
                    clientName: clientName,
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: isEven
            ? AppColors.primary
            : AppColors.primaryLight.withOpacity(0.4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            // N° Cmd
            Expanded(
              flex: 1,
              child: Text(
                order.orderId,
                style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 11),
              ),
            ),
            // Client
            Expanded(
              flex: 2,
              child: _Cell(clientName),
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
              child: _Cell(fmt.format(order.createdAt)),
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
      // Todo : check if the supplement is changed

      // Todo : updated the requested quantity

      // Todo : update the client solde when updating the qteLivre

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
