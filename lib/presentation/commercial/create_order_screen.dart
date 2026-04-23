import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/firestore_repository.dart' show PlafondException;
import '../../data/models/models.dart';

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  ClientModel? _client;
  String? _chantier;
  BetonChantierModel? _bc; // selected béton+price config
  String _betonName = '';
  String _status = AppConstants.statusInProgress;
  DateTime? _deliveryDateTime;

  final _qteCtrl = TextEditingController();
  bool _loading = false;

  // ── Derived plafond values ────────────────────────────────────────────────
  //
  // plafond          : hard ceiling (admin sets this)
  // plafondFake      : total COMMITTED amount across all active orders
  //                    we compare (plafondFake + orderCost) vs (plafond + 5% tolerance)
  // plafondDisponible: settled balance, decremented only on delivery
  // ─────────────────────────────────────────────────────────────────────────

  double get _plafond      => _client?.plafond          ?? 0;
  double get _solde        => _client?.plafondDisponible ?? 0;  // settled balance
  double get _restPermis   => _client?.plafondFake       ?? 0;  // already committed

  double get _tolerance    => _plafond * 0.05;                  // 5% tolerance
  double get _prixBeton    => _bc?.prix ?? 0;
  double get _qte          => double.tryParse(_qteCtrl.text) ?? 0;
  double get _orderCost    => _qte * _prixBeton;

  /// Available budget for new commitments = (plafond + tolerance) - plafondFake
  double get _budgetRestant => (_plafond + _tolerance) - _restPermis;

  /// Quantity the client can still commit to at the current béton price
  double get _qteDispo =>
      (_prixBeton > 0 && _budgetRestant > 0) ? (_budgetRestant / _prixBeton) : 0;

  /// True when this order would push plafondFake over the ceiling
  bool get _exceedsPlafond =>
      _client != null && _bc != null && _qte > 0 &&
          (_restPermis + _orderCost) > (_plafond + _tolerance);

  bool get _clientBlocked => _client?.isBlocked ?? false;

  bool get _canSubmit =>
      _client != null &&
          _chantier != null &&
          _bc != null &&
          _qte > 0 &&
          !_exceedsPlafond &&
          !_clientBlocked &&
          !_loading;

  @override
  void dispose() {
    _qteCtrl.dispose();
    super.dispose();
  }

  // ── Handlers ───────────────────────────────────────────────────────────────

  void _onClientChanged(ClientModel? c) {
    setState(() {
      _client = c;
      _chantier = null;
      _bc = null;
      _betonName = '';
      _qteCtrl.clear();
    });
  }

  void _onChantierChanged(String? ch) {
    setState(() {
      _chantier = ch;
      _bc = null;
      _betonName = '';
      _qteCtrl.clear();
    });
  }

  void _onBcChanged(BetonChantierModel? bc) {
    if (bc == null) return;
    final betons = ref.read(betonsProvider).value ?? [];
    final name = betons
        .firstWhere((b) => b.id == bc.betonId,
        orElse: () => BetonModel(id: '', name: bc.betonId, category: ''))
        .name;
    setState(() {
      _bc = bc;
      _betonName = name;
      _qteCtrl.clear(); // reset qty when béton changes
    });
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark()
            .copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.accent)),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark()
            .copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.accent)),
        child: child!,
      ),
    );
    if (!mounted) return;

    setState(() {
      _deliveryDateTime = time == null
          ? date
          : DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _loading = true);

    try {
      final commercial = await ref.read(currentCommercialProvider.future);
      if (commercial == null) throw Exception('Commercial introuvable');

      // Server-side plafond check inside transaction (guards against race conditions)
      await ref.read(firestoreRepoProvider).checkPlafondBeforeCreate(
        clientId: _client!.id,
        orderCost: _orderCost,
      );

      final order = OrderModel(
        id: '',
        orderId: '',
        beton: _betonName,
        betonId: _bc!.betonId,
        betonPrice: _prixBeton,
        chantier: _chantier!,
        clientId: _client!.id,
        commercialId: commercial.id,
        contact: '',
        contactPhone: '',
        createdAt: DateTime.now(),
        deliveryDate: _deliveryDateTime,
        qteDemande: _qte,
        qteLivre: 0,
        soldPaid: 0.0,
        status: _status,
        supplement: 0,
      );

      await ref.read(firestoreRepoProvider).createOrder(order);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Commande créée avec succès !'),
          backgroundColor: AppColors.statusDelivered,
        ));
        context.go('/commercial');
      }
    } on PlafondException catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.card,
            title: const Row(children: [
              Icon(Icons.block, color: AppColors.error, size: 20),
              SizedBox(width: 10),
              Text('Plafond dépassé'),
            ]),
            content: Text(e.message,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider);
    final betons = ref.watch(betonsProvider).value ?? [];

    final bcAsync = (_client != null && _chantier != null)
        ? ref.watch(betonChantiersByChantierProvider(
        (clientId: _client!.id, chantier: _chantier!)))
        : null;
    final availableBcs = bcAsync?.value ?? [];

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────────────
            Container(
              color: AppColors.primaryLight,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    onPressed: () => context.go('/commercial'),
                  ),
                  const Expanded(
                    child: Text(
                      'Commande Management',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // balance the back button
                ],
              ),
            ),

            // ── Form ───────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // 1 ── Client dropdown ────────────────────────────────
                    clientsAsync.when(
                      loading: () => const _DropdownSkeleton(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (clients) => _AppDropdown<ClientModel>(
                        value: _client,
                        hint: 'Sélectionner un client',
                        items: clients
                            .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.fullName),
                        ))
                            .toList(),
                        onChanged: _onClientChanged,
                      ),
                    ),

                    if (_clientBlocked) ...[
                      const SizedBox(height: 8),
                      _InlineBanner(
                        icon: Icons.block,
                        message: 'Ce client est bloqué.',
                        color: AppColors.error,
                      ),
                    ],

                    const SizedBox(height: 20),

                    // 2 ── Chantier dropdown ──────────────────────────────
                    _AppDropdown<String>(
                      value: _chantier,
                      hint: 'Sélectionner un chantier',
                      enabled: _client != null && !_clientBlocked,
                      items: (_client?.chantiers ?? [])
                          .map((ch) => DropdownMenuItem(value: ch, child: Text(ch)))
                          .toList(),
                      onChanged: _onChantierChanged,
                    ),

                    const SizedBox(height: 20),

                    // 3 ── Béton dropdown ─────────────────────────────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sélectionner un type de béton',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        if (_chantier == null)
                          _AppDropdown<BetonChantierModel>(
                            value: null,
                            hint: 'Sélectionner un chantier d\'abord',
                            enabled: false,
                            items: const [],
                            onChanged: null,
                          )
                        else if (bcAsync == null)
                          const _DropdownSkeleton()
                        else
                          bcAsync.when(
                            loading: () => const _DropdownSkeleton(),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (bcs) => _AppDropdown<BetonChantierModel>(
                              value: _bc,
                              hint: bcs.isEmpty
                                  ? 'Aucun béton configuré pour ce chantier'
                                  : 'Type de béton',
                              enabled: bcs.isNotEmpty,
                              items: bcs.map((bc) {
                                final beton = betons.firstWhere(
                                      (b) => b.id == bc.betonId,
                                  orElse: () =>
                                      BetonModel(id: '', name: bc.betonId, category: ''),
                                );
                                return DropdownMenuItem(
                                  value: bc,
                                  child: Text(beton.name),
                                );
                              }).toList(),
                              onChanged: _onBcChanged,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // 4 ── Info grid ──────────────────────────────────────
                    _InfoGrid(
                      plafond: _plafond,
                      solde: _solde,
                      restPermis: _restPermis,
                      prixBeton: _prixBeton,
                      qteDispo: _qteDispo,
                      budgetRestant: _budgetRestant,
                    ),

                    const SizedBox(height: 28),

                    // 5 ── Quantité demandée ──────────────────────────────
                    _FlatField(
                      controller: _qteCtrl,
                      label: 'Quantité demandée',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      enabled: _bc != null,
                      onChanged: (_) => setState(() {}),
                    ),

                    // Plafond exceeded warning
                    if (_exceedsPlafond) ...[
                      const SizedBox(height: 8),
                      _InlineBanner(
                        icon: Icons.money_off,
                        message:
                        'Plafond dépassé. '
                            'Déjà engagé : ${_restPermis.toStringAsFixed(0)} DH + '
                            'Cette commande : ${_orderCost.toStringAsFixed(0)} DH = '
                            '${(_restPermis + _orderCost).toStringAsFixed(0)} DH '
                            '> Plafond autorisé : ${(_plafond + _tolerance).toStringAsFixed(0)} DH.',
                        color: AppColors.error,
                      ),
                    ] else if (_bc != null && _qte > 0) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Coût : ${_orderCost.toStringAsFixed(0)} DH  •  '
                              'Budget restant : ${_budgetRestant.toStringAsFixed(0)} DH',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // 6 ── Statut dropdown ────────────────────────────────
                    _AppDropdown<String>(
                      value: _status,
                      hint: 'Statut',
                      items: const [
                        DropdownMenuItem(
                            value: AppConstants.statusPending,
                            child: Text('En attente')),
                        DropdownMenuItem(
                            value: AppConstants.statusInProgress,
                            child: Text('En cours')),
                        DropdownMenuItem(
                            value: AppConstants.statusDelivered,
                            child: Text('Livré')),
                        DropdownMenuItem(
                            value: AppConstants.statusCanceled,
                            child: Text('Annulé')),
                      ],
                      onChanged: (v) => setState(() => _status = v ?? _status),
                    ),

                    const SizedBox(height: 20),

                    // 7 ── Date / heure de livraison ──────────────────────
                    _DateTimeField(
                      value: _deliveryDateTime,
                      onTap: _pickDateTime,
                      onClear: () => setState(() => _deliveryDateTime = null),
                    ),

                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _pickDateTime,
                      child: Text(
                        'Date de livraison',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary.withOpacity(0.7),
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.textSecondary.withOpacity(0.4),
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // 8 ── Submit ─────────────────────────────────────────
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _canSubmit ? _submit : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _canSubmit
                              ? const Color(0xFF4A5568)
                              : AppColors.textMuted.withOpacity(0.4),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5),
                        ),
                        child: _loading
                            ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                            : const Text('Crée commande'),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info grid ────────────────────────────────────────────────────────────────
// Row 1: Plafond (ceiling) / Solde disponible (settled) / Déjà engagé (fake)
// Row 2: Prix Béton / Qté disponible / Budget restant

class _InfoGrid extends StatelessWidget {
  final double plafond;
  final double solde;
  final double restPermis;   // = plafondFake (committed)
  final double prixBeton;
  final double qteDispo;
  final double budgetRestant;

  const _InfoGrid({
    required this.plafond,
    required this.solde,
    required this.restPermis,
    required this.prixBeton,
    required this.qteDispo,
    required this.budgetRestant,
  });

  @override
  Widget build(BuildContext context) {
    final engagedPct = plafond > 0 ? (restPermis / plafond).clamp(0.0, 1.5) : 0.0;
    final engagedColor = engagedPct > 0.95
        ? AppColors.error
        : engagedPct > 0.75
        ? AppColors.warning
        : AppColors.textSecondary;

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _InfoCell(label: 'Plafond :', value: plafond)),
            const SizedBox(width: 12),
            Expanded(child: _InfoCell(label: 'Solde :', value: solde)),
            const SizedBox(width: 12),
            Expanded(child: _InfoCell(
              label: 'Déjà engagé :',
              value: restPermis,
              valueColor: engagedColor,
            )),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _InfoCell(label: 'Prix Béton :', value: prixBeton)),
            const SizedBox(width: 12),
            Expanded(child: _InfoCell(
              label: 'Qté dispo :',
              value: qteDispo,
              unit: 'ton',
              valueColor: qteDispo <= 0 ? AppColors.error : null,
            )),
            const SizedBox(width: 12),
            Expanded(child: _InfoCell(
              label: 'Budget restant :',
              value: budgetRestant,
              valueColor: budgetRestant <= 0 ? AppColors.error : AppColors.statusDelivered,
            )),
          ],
        ),
      ],
    );
  }
}

class _InfoCell extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color? valueColor;

  const _InfoCell({
    required this.label,
    required this.value,
    this.unit = '',
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(
          unit.isNotEmpty
              ? '${value.toStringAsFixed(1)} $unit'
              : value.toStringAsFixed(1),
          style: TextStyle(
              color: valueColor ?? AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        const Divider(height: 1, thickness: 1, color: AppColors.divider),
      ],
    );
  }
}

// ── Flat underline dropdown (matches image style) ───────────────────────────────

class _AppDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool enabled;

  const _AppDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
          isExpanded: true,
          dropdownColor: AppColors.card,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: enabled ? AppColors.accent : AppColors.textMuted,
          ),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          items: enabled ? items : [],
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}

// ── Flat labeled text field ─────────────────────────────────────────────────────

class _FlatField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  const _FlatField({
    required this.controller,
    required this.label,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: enabled,
          onChanged: onChanged,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
          decoration: const InputDecoration(
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.divider),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.divider),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.accent, width: 2),
            ),
            disabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.divider),
            ),
            isDense: true,
            contentPadding: EdgeInsets.only(bottom: 8, top: 4),
          ),
        ),
      ],
    );
  }
}

// ── Date/time display field ─────────────────────────────────────────────────────

class _DateTimeField extends StatelessWidget {
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateTimeField({
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final label = value == null
        ? '--/--/----  --:--'
        : DateFormat('dd/MM/yyyy  HH:mm').format(value!);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: value == null ? AppColors.textMuted : AppColors.textPrimary,
                    fontSize: 15,
                  ),
                ),
              ),
              if (value != null)
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(height: 1, thickness: 1, color: AppColors.divider),
        ],
      ),
    );
  }
}

// ── Inline banner (warning / error) ────────────────────────────────────────────

class _InlineBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _InlineBanner({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: color, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

// ── Loading skeleton for dropdowns ─────────────────────────────────────────────

class _DropdownSkeleton extends StatelessWidget {
  const _DropdownSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.textMuted),
        ),
      ),
    );
  }
}
