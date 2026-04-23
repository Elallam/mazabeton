import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../shared/widgets/shared_widgets.dart';
import '../shared/dialogs/order_detail_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AdminOrdersScreen
// ─────────────────────────────────────────────────────────────────────────────

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
  bool _tableMode = false; // false = cards, true = table

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Helper: is a date "today" ────────────────────────────────────────────
  bool _isToday(DateTime? dt) {
    if (dt == null) return false;
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  // ── Resolve display names ────────────────────────────────────────────────
  String _clientName(String id, List<ClientModel> clients) =>
      clients.firstWhere((c) => c.id == id,
          orElse: () => ClientModel(
              id: id, name: id, firstName: '', phone: '', company: '',
              address: '', managerName: '', contactName: '', contactPhone: '',
              plafond: 0, plafondDisponible: 0, plafondFake: 0,
              isBlocked: false, isDeleted: false, chantiers: [])).fullName;

  String _staffName(String id, List<CommercialModel> staff) =>
      staff.firstWhere((s) => s.id == id,
          orElse: () => CommercialModel(
              id: id, firstname: '', name: id,
              email: '', phone: '', address: '', role: '', password: '')).fullName;

  // ── Build PDF matching the uploaded file format ──────────────────────────
  Future<void> _downloadPdf(
      List<OrderModel> orders,
      List<ClientModel> clients,
      List<CommercialModel> staff,
      String tabLabel,
      ) async {
    final dateTimeFmt = DateFormat('dd-MM-yyyy HH:mm');
    final pdf = pw.Document();

    // Column headers — same order as the uploaded PDF
    const headers = [
      'Client', 'Chantier', 'Type de béton',
      'Qte demandée', 'Qte livrée', 'Date de livraison',
      'Contact', 'Tél Contact', 'Status', 'Suivi par', 'Supplément',
    ];

    // Column flex widths (relative)
    const colWidths = [
      3.0, 2.5, 3.0,   // Client / Chantier / Béton
      1.5, 1.5, 2.5,   // Qte dem / Qte livr / Date
      2.0, 2.0, 1.5,   // Contact / Tel / Status
      2.0, 1.5,         // Suivi par / Supplément
    ];

    final totalFlex = colWidths.fold(0.0, (a, b) => a + b);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (ctx) {
          return [
            // Title header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'MAZABETON : Commandes $tabLabel',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ),
            pw.SizedBox(height: 10),

            // Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                for (int i = 0; i < colWidths.length; i++)
                  i: pw.FlexColumnWidth(colWidths[i]),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: headers.map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                    child: pw.Text(
                      h,
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  )).toList(),
                ),

                // Data rows
                ...orders.map((o) {
                  final client   = _clientName(o.clientId, clients);
                  final suivi    = _staffName(o.commercialId, staff);
                  final isToday  = _isToday(o.deliveryDate);
                  final isActive = o.status == 'pending' || o.status == 'in_progress';
                  // Red background: active order with delivery date = today
                  final highlight = isActive && isToday;

                  final bg = highlight
                      ? PdfColors.red100
                      : PdfColors.white;

                  String statusLabel;
                  switch (o.status) {
                    case 'pending':    statusLabel = 'en attente'; break;
                    case 'in_progress':statusLabel = 'en cours';   break;
                    case 'delivered':  statusLabel = 'livré';      break;
                    case 'canceled':   statusLabel = 'annulé';     break;
                    default:           statusLabel = o.status;
                  }

                  final cells = [
                    client,
                    o.chantier,
                    o.beton,
                    o.qteDemande.toStringAsFixed(1),
                    o.qteLivre.toStringAsFixed(1),
                    o.deliveryDate != null
                        ? dateTimeFmt.format(o.deliveryDate!)
                        : '—',
                    o.contact.isNotEmpty ? o.contact : '—',
                    o.contactPhone.isNotEmpty ? o.contactPhone : '—',
                    statusLabel,
                    suivi,
                    o.supplement.toStringAsFixed(1),
                  ];

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bg),
                    children: cells.map((cell) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 3, vertical: 4),
                      child: pw.Text(
                        cell,
                        style: pw.TextStyle(
                          fontSize: 7,
                          color: highlight ? PdfColors.red800 : PdfColors.black,
                          fontWeight: highlight
                              ? pw.FontWeight.bold
                              : pw.FontWeight.normal,
                        ),
                      ),
                    )).toList(),
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 10),
            if (orders.any((o) =>
            _isToday(o.deliveryDate) &&
                (o.status == 'pending' || o.status == 'in_progress')))
              pw.Row(children: [
                pw.Container(
                    width: 10, height: 10,
                    color: PdfColors.red100,
                    decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.red800))),
                pw.SizedBox(width: 6),
                pw.Text(
                  'Commandes en cours à livrer aujourd\'hui',
                  style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.red800,
                      fontWeight: pw.FontWeight.bold),
                ),
              ]),
          ];
        },
      ),
    );

    final filename =
        'mazabeton_${tabLabel.toLowerCase().replaceAll(' ', '_')}_'
        '${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

    await Printing.sharePdf(bytes: await pdf.save(), filename: filename);
  }

  @override
  Widget build(BuildContext context) {
    final filter  = ref.watch(orderFilterProvider);
    final clients = ref.watch(clientsProvider).value ?? [];
    final staff   = ref.watch(staffProvider).value ?? [];
    final betons  = ref.watch(betonsProvider).value ?? [];
    final isActiveTab = _tabController.index == 0;

    final selectedClient = filter.clientName == null
        ? null
        : clients.firstWhere((c) => c.id == filter.clientName,
        orElse: () => ClientModel(
            id: '', name: '', firstName: '', phone: '', company: '',
            address: '', managerName: '', contactName: '', contactPhone: '',
            plafond: 0, plafondDisponible: 0, plafondFake: 0,
            isBlocked: false, isDeleted: false, chantiers: []));

    final activeOrders   = ref.watch(activeOrdersProvider).value ?? [];
    final finishedOrders = ref.watch(finishedOrdersProvider).value ?? [];

    return Column(
      children: [
        // ── Filter band ─────────────────────────────────────────────────
        Container(
          color: AppColors.primaryLight,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search + view controls
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                      decoration: const InputDecoration(
                        hintText: 'Rechercher commandes...',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Consulter / Table toggle button
                  _ViewButton(
                    tableMode: _tableMode,
                    onToggle: () => setState(() => _tableMode = !_tableMode),
                  ),
                  const SizedBox(width: 6),

                  // Download button
                  _DownloadButton(
                    onTap: () {
                      final orders   = isActiveTab ? activeOrders : finishedOrders;
                      final filtered = _applyFilters(orders, clients, staff);
                      final label    = isActiveTab ? 'En cours' : 'livrées/Annulées';
                      _downloadPdf(filtered, clients, staff, label);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Row 1: client / commercial / date chips
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
                              clearBeton: true))
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
                              id: '', firstname: '',
                              name: filter.commercialName!,
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
                        onTap: () => ref.read(orderFilterProvider.notifier).reset(),
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

              // Row 2: chantier + béton chips (when client selected)
              if (selectedClient != null &&
                  (selectedClient.chantiers.isNotEmpty || betons.isNotEmpty)) ...[
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
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
                              onTap: () => ref
                                  .read(orderFilterProvider.notifier)
                                  .update(active
                                  ? filter.copyWith(clearChantier: true)
                                  : filter.copyWith(chantier: ch)),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.accentLight.withOpacity(0.18)
                                      : AppColors.card,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: active
                                        ? AppColors.accentLight
                                        : AppColors.divider,
                                    width: active ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(ch,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: active
                                          ? AppColors.accentLight
                                          : AppColors.textSecondary,
                                      fontWeight: active
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    )),
                              ),
                            ),
                          );
                        }),
                      ],
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
                              onTap: () => ref
                                  .read(orderFilterProvider.notifier)
                                  .update(active
                                  ? filter.copyWith(clearBeton: true)
                                  : filter.copyWith(betonType: b.name)),
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
                                child: Text(b.name,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: active
                                          ? AppColors.accent
                                          : AppColors.textSecondary,
                                      fontWeight: active
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    )),
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
              Tab(text: 'livrées/Annulées'),
            ],
          ),
        ),

        // ── Tab content ─────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildContent(
                ordersAsync: ref.watch(activeOrdersProvider),
                clients: clients,
                staff: staff,
                filter: filter,
              ),
              _buildContent(
                ordersAsync: ref.watch(finishedOrdersProvider),
                clients: clients,
                staff: staff,
                filter: filter,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Content: cards or table depending on _tableMode ──────────────────────
  Widget _buildContent({
    required AsyncValue<List<OrderModel>> ordersAsync,
    required List<ClientModel> clients,
    required List<CommercialModel> staff,
    required OrderFilter filter,
  }) {
    return ordersAsync.when(
      loading: () => const AppLoading(),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (orders) {
        final filtered = _applyFilters(orders, clients, staff);
        if (filtered.isEmpty) {
          return const EmptyState(
              message: 'Aucune commande trouvée', icon: Icons.inbox_outlined);
        }
        return _tableMode
            ? _OrderTable(
          orders: filtered,
          clients: clients,
          staff: staff,
          isToday: _isToday,
        )
            : _OrderCards(
          orders: filtered,
          clients: clients,
          staff: staff,
          isToday: _isToday,
        );
      },
    );
  }

  // ── Shared filter logic ──────────────────────────────────────────────────
  List<OrderModel> _applyFilters(
      List<OrderModel> orders,
      List<ClientModel> clients,
      List<CommercialModel> staff,
      ) {
    return orders.where((o) {
      final client = clients.firstWhere((c) => c.id == o.clientId,
          orElse: () => ClientModel(
              id: '', name: o.clientId, firstName: '', phone: '', company: '',
              address: '', managerName: '', contactName: '', contactPhone: '',
              plafond: 0, plafondDisponible: 0, plafondFake: 0,
              isBlocked: false, isDeleted: false, chantiers: []));
      final commercial = staff.firstWhere((s) => s.id == o.commercialId,
          orElse: () => CommercialModel(
              id: '', firstname: '', name: o.commercialId,
              email: '', phone: '', address: '', role: '', password: ''));
      final filter = ref.read(orderFilterProvider);

      if (_searchQuery.isNotEmpty) {
        final match = client.fullName.toLowerCase().contains(_searchQuery) ||
            o.chantier.toLowerCase().contains(_searchQuery) ||
            o.beton.toLowerCase().contains(_searchQuery) ||
            commercial.fullName.toLowerCase().contains(_searchQuery);
        if (!match) return false;
      }
      if (filter.clientName != null && o.clientId != filter.clientName) return false;
      if (filter.chantier != null && o.chantier != filter.chantier) return false;
      if (filter.betonType != null && o.beton != filter.betonType) return false;
      if (filter.commercialName != null && o.commercialId != filter.commercialName) return false;
      if (filter.startDate != null && o.createdAt.isBefore(filter.startDate!)) return false;
      if (filter.endDate != null &&
          o.createdAt.isAfter(filter.endDate!.add(const Duration(days: 1)))) {
        return false;
      }
      return true;
    }).toList();
  }

  // ── Pickers ──────────────────────────────────────────────────────────────
  void _pickClient(List<ClientModel> clients) {
    String query = '';
    var filtered = clients
        .where((c) => c.company.toLowerCase().contains(query.toLowerCase()))
        .toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {


          return DraggableScrollableSheet(
            initialChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, scroll) => Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 12),
                const Text('Filtrer par client',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un client...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: AppColors.card,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setState(()  {
                      query = v;
                      filtered = clients
                          .where((c) => c.company.toLowerCase().contains(query.toLowerCase()))
                          .toList();
                    }),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                    child: Text('Aucun client trouvé',
                        style: TextStyle(color: AppColors.textMuted)),
                  )
                      : ListView(
                    controller: scroll,
                    children: filtered.map((c) => ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.accent.withOpacity(0.15),
                        child: Text(
                          c.firstName.isNotEmpty ? c.firstName[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(c.company,
                          style: const TextStyle(fontSize: 14)),
                      subtitle: Text(c.contactName,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
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
          );
        },
      ),
    );
  }

  void _pickCommercial(List<CommercialModel> staff) {
    final commercials = staff.where((s) => s.role == 'commercial').toList();
    String query = '';
    var filtered = List<CommercialModel>.from(commercials);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, scroll) => Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 12),
                const Text('Filtrer par commercial',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un commercial...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: AppColors.card,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setState(() {
                      query = v;
                      filtered = commercials
                          .where((s) => s.fullName.toLowerCase().contains(query.toLowerCase()))
                          .toList();
                    }),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                    child: Text('Aucun commercial trouvé',
                        style: TextStyle(color: AppColors.textMuted)),
                  )
                      : ListView(
                    controller: scroll,
                    children: filtered.map((s) => ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.accent.withOpacity(0.15),
                        child: Text(
                          s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(s.fullName,
                          style: const TextStyle(fontSize: 14)),
                      onTap: () {
                        ref.read(orderFilterProvider.notifier).update(
                          ref.read(orderFilterProvider).copyWith(
                              commercialName: s.id),
                        );
                        Navigator.pop(context);
                      },
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
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
        data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: AppColors.accent)),
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

// ─── Card view (original) ──────────────────────────────────────────────────────

class _OrderCards extends StatelessWidget {
  final List<OrderModel> orders;
  final List<ClientModel> clients;
  final List<CommercialModel> staff;
  final bool Function(DateTime?) isToday;

  const _OrderCards({
    required this.orders,
    required this.clients,
    required this.staff,
    required this.isToday,
  });

  String _clientName(String id) => clients.firstWhere((c) => c.id == id,
      orElse: () => ClientModel(
          id: id, name: id, firstName: '', phone: '', company: '',
          address: '', managerName: '', contactName: '', contactPhone: '',
          plafond: 0, plafondDisponible: 0, plafondFake: 0,
          isBlocked: false, isDeleted: false, chantiers: [])).fullName;

  String _staffName(String id) => staff.firstWhere((s) => s.id == id,
      orElse: () => CommercialModel(
          id: id, firstname: '', name: id,
          email: '', phone: '', address: '', role: '', password: '')).fullName;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (ctx, i) {
        final o = orders[i];
        final highlight = isToday(o.deliveryDate) && o.isActive;
        return Stack(
          children: [
            OrderCard(
              order: o,
              clientName: _clientName(o.clientId),
              commercialName: _staffName(o.commercialId),
              onTap: () => showDialog(
                context: ctx,
                builder: (_) => OrderDetailDialog(
                    order: o, clientName: _clientName(o.clientId)),
              ),
            ),
            // Red "today" badge on the card
            if (highlight)
              Positioned(
                top: 6, right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Livraison aujourd\'hui',
                    style: TextStyle(color: Colors.white,
                        fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─── Table view ────────────────────────────────────────────────────────────────

class _OrderTable extends StatefulWidget {
  final List<OrderModel> orders;
  final List<ClientModel> clients;
  final List<CommercialModel> staff;
  final bool Function(DateTime?) isToday;

  const _OrderTable({
    required this.orders,
    required this.clients,
    required this.staff,
    required this.isToday,
  });

  @override
  State<_OrderTable> createState() => _OrderTableState();
}

class _OrderTableState extends State<_OrderTable> {
  int _sortCol = 5; // default sort by delivery date
  bool _asc = true;

  // Column definitions: (label, flex)
  static const _cols = [
    ('Client',         2),
    ('Chantier',       2),
    ('Type béton',     2),
    ('Qte dem.',       1),
    ('Qte livr.',      1),
    ('Date livraison', 2),
    ('Contact',        2),
    ('Tél',            2),
    ('Statut',         1),
    ('Suivi par',      2),
    ('Supp.',          1),
  ];

  String _clientName(String id) => widget.clients.firstWhere((c) => c.id == id,
      orElse: () => ClientModel(
          id: id, name: id, firstName: '', phone: '', company: '',
          address: '', managerName: '', contactName: '', contactPhone: '',
          plafond: 0, plafondDisponible: 0, plafondFake: 0,
          isBlocked: false, isDeleted: false, chantiers: [])).fullName;

  String _staffName(String id) => widget.staff.firstWhere((s) => s.id == id,
      orElse: () => CommercialModel(
          id: id, firstname: '', name: id,
          email: '', phone: '', address: '', role: '', password: '')).fullName;

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':    return 'En attente';
      case 'in_progress':return 'En cours';
      case 'delivered':  return 'Livré';
      case 'canceled':   return 'Annulé';
      default: return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':    return AppColors.statusPending;
      case 'in_progress':return AppColors.statusInProgress;
      case 'delivered':  return AppColors.statusDelivered;
      case 'canceled':   return AppColors.statusCanceled;
      default: return AppColors.textMuted;
    }
  }

  List<OrderModel> get _sorted {
    final list = List<OrderModel>.from(widget.orders);
    list.sort((a, b) {
      int cmp;
      switch (_sortCol) {
        case 0: cmp = _clientName(a.clientId).compareTo(_clientName(b.clientId)); break;
        case 1: cmp = a.chantier.compareTo(b.chantier); break;
        case 2: cmp = a.beton.compareTo(b.beton); break;
        case 3: cmp = a.qteDemande.compareTo(b.qteDemande); break;
        case 4: cmp = a.qteLivre.compareTo(b.qteLivre); break;
        case 5:
          final ad = a.deliveryDate?.millisecondsSinceEpoch ?? 0;
          final bd = b.deliveryDate?.millisecondsSinceEpoch ?? 0;
          cmp = ad.compareTo(bd); break;
        case 6: cmp = a.contact.compareTo(b.contact); break;
        case 7: cmp = a.contactPhone.compareTo(b.contactPhone); break;
        case 8: cmp = a.status.compareTo(b.status); break;
        case 9: cmp = _staffName(a.commercialId).compareTo(_staffName(b.commercialId)); break;
        case 10:cmp = a.supplement.compareTo(b.supplement); break;
        default: cmp = 0;
      }
      return _asc ? cmp : -cmp;
    });
    return list;
  }

  void _onSort(int col) => setState(() {
    if (_sortCol == col) {
      _asc = !_asc;
    } else {
      _sortCol = col;
      _asc = true;
    }
  });

  @override
  Widget build(BuildContext context) {
    final rows = _sorted;
    final fmt = DateFormat('dd/MM/yy HH:mm');

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          // Ensure the table fills screen width at minimum
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──────────────────────────────────────────
              Container(
                color: AppColors.card,
                child: Row(
                  children: _cols.asMap().entries.map((e) {
                    final idx   = e.key;
                    final label = e.value.$1;
                    final flex  = e.value.$2;
                    return SizedBox(
                      width: flex * 72.0,
                      child: GestureDetector(
                        onTap: () => _onSort(idx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(
                                right: BorderSide(
                                    color: AppColors.divider, width: 0.5)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _sortCol == idx
                                        ? AppColors.accent
                                        : AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_sortCol == idx)
                                Icon(
                                  _asc ? Icons.arrow_upward : Icons.arrow_downward,
                                  size: 10,
                                  color: AppColors.accent,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 1, thickness: 1),

              // ── Data rows ──────────────────────────────────────────
              ...rows.asMap().entries.map((entry) {
                final i = entry.key;
                final o = entry.value;
                final highlight = widget.isToday(o.deliveryDate) && o.isActive;
                final isEven    = i % 2 == 0;

                // Background
                Color rowBg;
                if (highlight) {
                  rowBg = AppColors.error.withOpacity(0.12);
                } else if (isEven) {
                  rowBg = AppColors.primary;
                } else {
                  rowBg = AppColors.primaryLight.withOpacity(0.4);
                }

                final cells = [
                  _clientName(o.clientId),
                  o.chantier,
                  o.beton,
                  '${o.qteDemande.toStringAsFixed(1)} ton',
                  '${o.qteLivre.toStringAsFixed(1)} ton',
                  o.deliveryDate != null ? fmt.format(o.deliveryDate!) : '—',
                  o.contact.isNotEmpty ? o.contact : '—',
                  o.contactPhone.isNotEmpty ? o.contactPhone : '—',
                  _statusLabel(o.status),
                  _staffName(o.commercialId),
                  '${o.supplement.toStringAsFixed(1)} ton',
                ];

                return GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => OrderDetailDialog(
                        order: o, clientName: _clientName(o.clientId)),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      border: highlight
                          ? Border(
                          left: BorderSide(
                              color: AppColors.error, width: 3))
                          : null,
                    ),
                    child: Row(
                      children: cells.asMap().entries.map((ce) {
                        final cidx = ce.key;
                        final cell = ce.value;
                        final flex = _cols[cidx].$2;
                        final isStatus = cidx == 8;

                        return SizedBox(
                          width: flex * 72.0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                    color: AppColors.divider
                                        .withOpacity(0.5),
                                    width: 0.5),
                                bottom: BorderSide(
                                    color: AppColors.divider
                                        .withOpacity(0.3),
                                    width: 0.5),
                              ),
                            ),
                            child: isStatus
                                ? _StatusPill(
                              label: cell,
                              color: _statusColor(o.status),
                            )
                                : Text(
                              cell,
                              style: TextStyle(
                                fontSize: 11,
                                color: highlight
                                    ? AppColors.error
                                    : AppColors.textSecondary,
                                fontWeight: highlight
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              }),

              // ── Legend ──────────────────────────────────────────────
              if (rows.any((o) =>
              widget.isToday(o.deliveryDate) && o.isActive))
                Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 10, color: AppColors.error),
                      SizedBox(width: 8),
                      Text(
                        'Commandes en cours à livrer aujourd\'hui',
                        style: TextStyle(
                            color: AppColors.error,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Status pill for table ─────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ─── View toggle button (Consulter / Cartes) ──────────────────────────────────

class _ViewButton extends StatelessWidget {
  final bool tableMode;
  final VoidCallback onToggle;

  const _ViewButton({required this.tableMode, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: tableMode
              ? AppColors.accent.withOpacity(0.15)
              : AppColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: tableMode ? AppColors.accent : AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tableMode ? Icons.view_agenda_outlined : Icons.table_rows_outlined,
              size: 15,
              color: tableMode ? AppColors.accent : AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              tableMode ? 'Cartes' : 'Consulter',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tableMode ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Download button ──────────────────────────────────────────────────────────

class _DownloadButton extends StatelessWidget {
  final VoidCallback onTap;
  const _DownloadButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accentGold.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.accentGold.withOpacity(0.5)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_outlined, size: 15, color: AppColors.accentGold),
            SizedBox(width: 5),
            Text(
              'PDF',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentGold),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter chip with optional ✕ ──────────────────────────────────────────────

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
              color: active ? AppColors.accent.withOpacity(0.5) : AppColors.divider),
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
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (active && onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 13, color: AppColors.accent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}