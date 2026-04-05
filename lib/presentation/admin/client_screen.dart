import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../shared/widgets/shared_widgets.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider);

    return Scaffold(
      body: Column(
        children: [
          // Search bar
          Container(
            color: AppColors.primaryLight,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Rechercher un client...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),

          // List
          Expanded(
            child: clientsAsync.when(
              loading: () => const AppLoading(),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (clients) {
                final filtered = _search.isEmpty
                    ? clients
                    : clients.where((c) =>
                c.fullName.toLowerCase().contains(_search) ||
                    c.company.toLowerCase().contains(_search) ||
                    c.phone.contains(_search)).toList();

                if (filtered.isEmpty) {
                  return const EmptyState(
                    message: 'Aucun client trouvé',
                    icon: Icons.person_search_outlined,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _ClientCard(
                    client: filtered[i],
                    index: i,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showClientForm(context, null),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Nouveau client'),
      ),
    );
  }

  void _showClientForm(BuildContext context, ClientModel? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ClientFormSheet(existing: existing),
    );
  }
}

// ─── Client Card ──────────────────────────────────────────────────────────────

class _ClientCard extends ConsumerWidget {
  final ClientModel client;
  final int index;
  const _ClientCard({required this.client, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plafondPct = client.plafond > 0
        ? ((client.plafond - client.plafondDisponible) / client.plafond).clamp(0.0, 1.0)
        : 0.0;
    final barColor = plafondPct > 0.8
        ? AppColors.error
        : plafondPct > 0.5
        ? AppColors.warning
        : AppColors.statusDelivered;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetail(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.accent.withOpacity(0.15),
                    child: Text(
                      client.firstName.isNotEmpty ? client.firstName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              client.contactName,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            SizedBox(width: 16,),
                            //Todo : update the design.
                            phoneButton(client.contactPhone),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          client.company,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // Status badges
                  if (client.isBlocked)
                    _Badge(label: 'Bloqué', color: AppColors.error)
                  else if (client.hasReachedPlafond)
                    _Badge(label: 'Plafond atteint', color: AppColors.warning),
                  PopupMenuButton<String>(
                    color: AppColors.card,
                    icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
                    onSelected: (v) => _handleMenu(context, ref, v),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: _MenuRow(icon: Icons.edit_outlined, label: 'Modifier')),
                      const PopupMenuItem(value: 'chantiers', child: _MenuRow(icon: Icons.location_city_outlined, label: 'Chantiers')),
                      const PopupMenuItem(value: 'plafond', child: _MenuRow(icon: Icons.price_change_outlined, label: 'Ajuster le plafond')),
                      PopupMenuItem(
                        value: 'block',
                        child: _MenuRow(
                          icon: client.isBlocked ? Icons.lock_open_outlined : Icons.block_outlined,
                          label: client.isBlocked ? 'Débloquer' : 'Bloquer',
                          color: AppColors.warning,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: _MenuRow(icon: Icons.delete_outline, label: 'Supprimer', color: AppColors.error),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Info chips
              Row(
                children: [
                  _InfoChip(icon: Icons.phone_outlined, label: client.phone),
                  const SizedBox(width: 8),
                  _InfoChip(icon: Icons.location_on_outlined, label: client.address.isNotEmpty ? client.address : '—'),
                ],
              ),
              const SizedBox(height: 12),

              // Plafond bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Plafond', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  Text(
                    '${client.plafondDisponible.toStringAsFixed(0)} / ${client.plafond.toStringAsFixed(0)} DH',
                    style: TextStyle(
                      color: barColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: plafondPct,
                  backgroundColor: AppColors.divider,
                  valueColor: AlwaysStoppedAnimation(barColor),
                  minHeight: 5,
                ),
              ),

              // Chantiers chips
              if (client.chantiers.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: client.chantiers.map((ch) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Text(ch, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate(delay: Duration(milliseconds: 40 * index)).fadeIn(duration: 400.ms).slideY(begin: 0.15, end: 0);
  }

  void _handleMenu(BuildContext context, WidgetRef ref, String value) async {
    switch (value) {
      case 'edit':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.card,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (_) => _ClientFormSheet(existing: client),
        );
        break;
      case 'chantiers':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.card,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (_) => _ChantiersSheet(client: client),
        );
        break;
      case 'plafond':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.card,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (_) => _PlafondSheet(client: client),
        );
        break;
      case 'block':
        await ref.read(firestoreRepoProvider).toggleClientBlock(client.id, !client.isBlocked);
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.card,
            title: const Text('Supprimer le client'),
            content: Text('Supprimer ${client.fullName} ? Cette action est irréversible.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Supprimer', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await ref.read(firestoreRepoProvider).softDeleteClient(client.id);
        }
        break;
    }
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ClientDetailSheet(client: client),
    );
  }
}

// ─── Client Detail Sheet ──────────────────────────────────────────────────────

class _ClientDetailSheet extends ConsumerWidget {
  final ClientModel client;
  const _ClientDetailSheet({required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final betonChantiersAsync = ref.watch(betonChantiersProvider(client.id));
    final betonsAsync = ref.watch(betonsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),
          Text(client.fullName, style: Theme.of(context).textTheme.titleLarge),
          Text(client.company, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          _DetailRow(icon: Icons.phone_outlined, label: 'Téléphone', value: client.phone),
          _DetailRow(icon: Icons.location_on_outlined, label: 'Adresse', value: client.address.isEmpty ? '—' : client.address),
          _DetailRow(icon: Icons.manage_accounts_outlined, label: 'Responsable', value: client.managerName.isEmpty ? '—' : client.managerName),
          _DetailRow(icon: Icons.contact_phone_outlined, label: 'Contact', value: client.contactName.isEmpty ? '—' : '${client.contactName} — ${client.contactPhone}'),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatBox(label: 'Plafond total', value: '${client.plafond.toStringAsFixed(0)} DH', color: AppColors.accent)),
              const SizedBox(width: 10),
              Expanded(child: _StatBox(label: 'Disponible', value: '${client.plafondDisponible.toStringAsFixed(0)} DH', color: AppColors.statusDelivered)),
              const SizedBox(width: 10),
              Expanded(child: _StatBox(label: 'Plafond fictif', value: '${client.plafondFake.toStringAsFixed(0)} DH', color: AppColors.accentGold)),
            ],
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Prix béton par chantier'),
          const SizedBox(height: 12),
          betonChantiersAsync.when(
            loading: () => const AppLoading(),
            error: (_, __) => const SizedBox.shrink(),
            data: (bcs) {
              final betons = betonsAsync.value ?? [];
              if (bcs.isEmpty) {
                return const Text('Aucun prix configuré', style: TextStyle(color: AppColors.textMuted, fontSize: 13));
              }
              return Column(
                children: bcs.map((bc) {
                  final beton = betons.firstWhere((b) => b.id == bc.betonId,
                      orElse: () => BetonModel(id: '', name: bc.betonId, category: ''));
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(beton.name, style: const TextStyle(fontSize: 13))),
                        Text(bc.chantier, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        const SizedBox(width: 12),
                        Text('${bc.prix.toStringAsFixed(0)} DH/ton',
                            style: const TextStyle(color: AppColors.accentGold, fontWeight: FontWeight.w700, fontSize: 13)),
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

// ─── Client Form Sheet (create / edit) ───────────────────────────────────────

class _ClientFormSheet extends ConsumerStatefulWidget {
  final ClientModel? existing;
  const _ClientFormSheet({this.existing});

  @override
  ConsumerState<_ClientFormSheet> createState() => _ClientFormSheetState();
}

class _ClientFormSheetState extends ConsumerState<_ClientFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _company;
  late final TextEditingController _address;
  late final TextEditingController _managerName;
  late final TextEditingController _contactName;
  late final TextEditingController _contactPhone;
  late final TextEditingController _plafond;
  late final TextEditingController _plafondFake;
  bool _loading = false;

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _firstName   = TextEditingController(text: c?.firstName ?? '');
    _name        = TextEditingController(text: c?.name ?? '');
    _phone       = TextEditingController(text: c?.phone ?? '');
    _company     = TextEditingController(text: c?.company ?? '');
    _address     = TextEditingController(text: c?.address ?? '');
    _managerName = TextEditingController(text: c?.managerName ?? '');
    _contactName = TextEditingController(text: c?.contactName ?? '');
    _contactPhone= TextEditingController(text: c?.contactPhone ?? '');
    _plafond     = TextEditingController(text: c?.plafond.toStringAsFixed(0) ?? '0');
    _plafondFake = TextEditingController(text: c?.plafondFake.toStringAsFixed(0) ?? '0');
  }

  @override
  void dispose() {
    for (final ctrl in [_firstName, _name, _phone, _company, _address,
      _managerName, _contactName, _contactPhone, _plafond, _plafondFake]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final plafondVal = double.tryParse(_plafond.text) ?? 0;
      final plafondFakeVal = double.tryParse(_plafondFake.text) ?? 0;

      if (isEditing) {
        await ref.read(firestoreRepoProvider).updateClient(widget.existing!.id, {
          'firstName': _firstName.text.trim(),
          'name': _name.text.trim(),
          'phone': _phone.text.trim(),
          'company': _company.text.trim(),
          'address': _address.text.trim(),
          'managerName': _managerName.text.trim(),
          'contactName': _contactName.text.trim(),
          'contactPhone': _contactPhone.text.trim(),
          'plafond': plafondVal,
          'plafondFake': plafondFakeVal,
        });
      } else {
        final client = ClientModel(
          id: '',
          firstName: _firstName.text.trim(),
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          company: _company.text.trim(),
          address: _address.text.trim(),
          managerName: _managerName.text.trim(),
          contactName: _contactName.text.trim(),
          contactPhone: _contactPhone.text.trim(),
          plafond: plafondVal,
          plafondDisponible: plafondVal,
          plafondFake: plafondFakeVal,
          isBlocked: false,
          isDeleted: false,
          chantiers: [],
        );
        await ref.read(firestoreRepoProvider).createClient(client);
      }
      if (mounted) Navigator.pop(context);
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
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text(
                isEditing ? 'Modifier le client' : 'Nouveau client',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),

              _Label('Identité'),
              Row(children: [
                Expanded(child: _Field(_firstName, 'Prénom *', Icons.person_outline)),
                const SizedBox(width: 12),
                Expanded(child: _Field(_name, 'Nom *', Icons.person_outline)),
              ]),
              const SizedBox(height: 12),
              _Field(_company, 'Entreprise', Icons.business_outlined),
              const SizedBox(height: 12),
              _Field(_phone, 'Téléphone *', Icons.phone_outlined, type: TextInputType.phone),
              const SizedBox(height: 12),
              _Field(_address, 'Adresse', Icons.location_on_outlined),
              const SizedBox(height: 20),

              _Label('Contacts'),
              _Field(_managerName, 'Nom du responsable', Icons.manage_accounts_outlined),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _Field(_contactName, 'Nom contact', Icons.contact_page_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _Field(_contactPhone, 'Tél. contact', Icons.phone_in_talk_outlined, type: TextInputType.phone)),
              ]),
              const SizedBox(height: 20),

              _Label('Plafond de crédit'),
              Row(children: [
                Expanded(child: _Field(_plafond, 'Plafond (DH) *', Icons.credit_score_outlined, type: TextInputType.number, required: true)),
                const SizedBox(width: 12),
                Expanded(child: _Field(_plafondFake, 'Plafond fictif (DH)', Icons.show_chart_outlined, type: TextInputType.number)),
              ]),
              const SizedBox(height: 28),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(isEditing ? 'ENREGISTRER' : 'CRÉER LE CLIENT',
                      style: const TextStyle(letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Chantiers Sheet ──────────────────────────────────────────────────────────

class _ChantiersSheet extends ConsumerStatefulWidget {
  final ClientModel client;
  const _ChantiersSheet({required this.client});

  @override
  ConsumerState<_ChantiersSheet> createState() => _ChantiersSheetState();
}

class _ChantiersSheetState extends ConsumerState<_ChantiersSheet> {
  final _nameCtrl = TextEditingController();
  late List<String> _chantiers;
  String? _expandedChantier;

  @override
  void initState() {
    super.initState();
    _chantiers = List.from(widget.client.chantiers);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _addChantier() async {
    final val = _nameCtrl.text.trim();
    if (val.isEmpty || _chantiers.contains(val)) return;
    setState(() {
      _chantiers.add(val);
      _expandedChantier = val;
    });
    _nameCtrl.clear();
    await ref.read(firestoreRepoProvider).updateClient(
      widget.client.id, {'chantiers': _chantiers},
    );
  }

  Future<void> _removeChantier(String ch) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Supprimer le chantier'),
        content: Text(
          'Supprimer "$ch" ? Les bétons et prix associés seront également supprimés.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      _chantiers.remove(ch);
      if (_expandedChantier == ch) _expandedChantier = null;
    });
    await ref.read(firestoreRepoProvider).updateClient(
      widget.client.id, {'chantiers': _chantiers},
    );
    // Delete all betonChantier entries for this chantier
    final bcs = await ref.read(firestoreRepoProvider).getBetonChantiers(widget.client.id, ch);
    for (final bc in bcs) {
      await ref.read(firestoreRepoProvider).deleteBetonChantier(bc.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final betonChantiersAsync = ref.watch(betonChantiersProvider(widget.client.id));
    final betonsAsync = ref.watch(betonsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scroll) => Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4,
                        decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 16),
                  Text('Chantiers — ${widget.client.fullName}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text(
                    'Ajoutez des chantiers, puis configurez les bétons et prix pour chacun.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  // Add chantier input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Nom du chantier',
                            prefixIcon: Icon(Icons.add_location_outlined),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _addChantier(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _addChantier,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        child: const Text('Ajouter'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                ],
              ),
            ),

            // Chantier list with béton config
            Expanded(
              child: _chantiers.isEmpty
                  ? const Center(
                child: Text('Aucun chantier. Ajoutez-en un ci-dessus.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              )
                  : ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _chantiers.length,
                itemBuilder: (ctx, i) {
                  final ch = _chantiers[i];
                  final isExpanded = _expandedChantier == ch;
                  final bcs = betonChantiersAsync.value
                      ?.where((bc) => bc.chantier == ch)
                      .toList() ??
                      [];
                  final betons = betonsAsync.value ?? [];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      children: [
                        // Chantier header row
                        InkWell(
                          borderRadius: isExpanded
                              ? const BorderRadius.vertical(top: Radius.circular(16))
                              : BorderRadius.circular(16),
                          onTap: () => setState(() {
                            _expandedChantier = isExpanded ? null : ch;
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.location_city_outlined,
                                      color: AppColors.accent, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(ch,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600, fontSize: 15)),
                                      Text(
                                        bcs.isEmpty
                                            ? 'Aucun béton configuré'
                                            : '${bcs.length} béton(s) configuré(s)',
                                        style: TextStyle(
                                          color: bcs.isEmpty
                                              ? AppColors.warning
                                              : AppColors.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: AppColors.error, size: 20),
                                  onPressed: () => _removeChantier(ch),
                                  tooltip: 'Supprimer le chantier',
                                ),
                                Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Expanded: béton config panel
                        if (isExpanded) ...[
                          const Divider(height: 1),
                          _BetonPriceConfig(
                            client: widget.client,
                            chantier: ch,
                            bcs: bcs,
                            betons: betons,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Inline béton + price configurator for one chantier
class _BetonPriceConfig extends ConsumerStatefulWidget {
  final ClientModel client;
  final String chantier;
  final List<BetonChantierModel> bcs;
  final List<BetonModel> betons;

  const _BetonPriceConfig({
    required this.client,
    required this.chantier,
    required this.bcs,
    required this.betons,
  });

  @override
  ConsumerState<_BetonPriceConfig> createState() => _BetonPriceConfigState();
}

class _BetonPriceConfigState extends ConsumerState<_BetonPriceConfig> {
  BetonModel? _selectedBeton;
  final _prixCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _prixCtrl.dispose();
    super.dispose();
  }

  Future<void> _addBeton() async {
    if (_selectedBeton == null || _prixCtrl.text.trim().isEmpty) return;
    final prix = double.tryParse(_prixCtrl.text.trim()) ?? 0;
    if (prix <= 0) return;

    setState(() => _saving = true);
    try {
      await ref.read(firestoreRepoProvider).setBetonChantierPrice(
        BetonChantierModel(
          id: '',
          betonId: _selectedBeton!.id,
          chantier: widget.chantier,
          clientId: widget.client.id,
          prix: prix,
        ),
      );
      setState(() {
        _selectedBeton = null;
        _prixCtrl.clear();
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeBc(BetonChantierModel bc) async {
    await ref.read(firestoreRepoProvider).deleteBetonChantier(bc.id);
  }

  Future<void> _editPrice(BetonChantierModel bc) async {
    final ctrl = TextEditingController(text: bc.prix.toStringAsFixed(0));
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Modifier le prix — ${widget.betons.firstWhere((b) => b.id == bc.betonId, orElse: () => BetonModel(id: '', name: bc.betonId, category: '')).name}'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nouveau prix (DH/ton)',
            prefixIcon: Icon(Icons.price_change_outlined),
            suffixText: 'DH/ton',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final newPrice = double.tryParse(ctrl.text.trim()) ?? 0;
              if (newPrice > 0) {
                await ref.read(firestoreRepoProvider).setBetonChantierPrice(
                  BetonChantierModel(
                    id: bc.id,
                    betonId: bc.betonId,
                    chantier: bc.chantier,
                    clientId: bc.clientId,
                    prix: newPrice,
                  ),
                );
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Betons not yet assigned to this chantier
    final assignedIds = widget.bcs.map((bc) => bc.betonId).toSet();
    final available = widget.betons.where((b) => !assignedIds.contains(b.id)).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Configured bétons list
          if (widget.bcs.isNotEmpty) ...[
            const Text('Bétons configurés',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            ...widget.bcs.map((bc) {
              final beton = widget.betons.firstWhere(
                    (b) => b.id == bc.betonId,
                orElse: () => BetonModel(id: '', name: bc.betonId, category: ''),
              );
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    // Beton name + category
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(beton.name,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          if (beton.category.isNotEmpty)
                            Text(beton.category,
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    // Price
                    GestureDetector(
                      onTap: () => _editPrice(bc),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.accentGold.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${bc.prix.toStringAsFixed(0)} DH/ton',
                              style: const TextStyle(
                                  color: AppColors.accentGold,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.edit, size: 12, color: AppColors.accentGold),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Remove
                    GestureDetector(
                      onTap: () => _removeBc(bc),
                      child: const Icon(Icons.close, size: 18, color: AppColors.error),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
          ],

          // Add new béton
          if (available.isEmpty && widget.bcs.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.statusDelivered.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.statusDelivered.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: AppColors.statusDelivered, size: 16),
                  SizedBox(width: 8),
                  Text('Tous les bétons sont configurés',
                      style: TextStyle(color: AppColors.statusDelivered, fontSize: 12)),
                ],
              ),
            )
          else ...[
            const Text('Ajouter un béton',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: DropdownButtonFormField<BetonModel>(
                    value: _selectedBeton,
                    dropdownColor: AppColors.card,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Béton',
                      prefixIcon: Icon(Icons.inventory_2_outlined, size: 18),
                      isDense: true,
                    ),
                    items: available.map((b) => DropdownMenuItem(
                      value: b,
                      child: Text(b.name, style: const TextStyle(fontSize: 13)),
                    )).toList(),
                    onChanged: (b) => setState(() => _selectedBeton = b),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _prixCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Prix/ton',
                      suffixText: 'DH',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _addBeton,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: Size.zero,
                    ),
                    child: _saving
                        ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.add, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PlafondSheet extends ConsumerStatefulWidget {
  final ClientModel client;
  const _PlafondSheet({required this.client});

  @override
  ConsumerState<_PlafondSheet> createState() => _PlafondSheetState();
}

class _PlafondSheetState extends ConsumerState<_PlafondSheet> {
  late final TextEditingController _plafond;
  late final TextEditingController _disponible;
  late final TextEditingController _fake;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _plafond    = TextEditingController(text: widget.client.plafond.toStringAsFixed(0));
    _disponible = TextEditingController(text: widget.client.plafondDisponible.toStringAsFixed(0));
    _fake       = TextEditingController(text: widget.client.plafondFake.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _plafond.dispose();
    _disponible.dispose();
    _fake.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await ref.read(firestoreRepoProvider).updateClient(widget.client.id, {
        'plafond': double.tryParse(_plafond.text) ?? widget.client.plafond,
        'plafondDisponible': double.tryParse(_disponible.text) ?? widget.client.plafondDisponible,
        'plafondFake': double.tryParse(_fake.text) ?? widget.client.plafondFake,
      });
      if (mounted) Navigator.pop(context);
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
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('Ajuster le plafond — ${widget.client.fullName}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          _Field(_plafond, 'Plafond total (DH)', Icons.credit_score_outlined, type: TextInputType.number),
          const SizedBox(height: 12),
          _Field(_disponible, 'Plafond disponible (DH)', Icons.account_balance_wallet_outlined, type: TextInputType.number),
          const SizedBox(height: 12),
          _Field(_fake, 'Plafond fictif (DH)', Icons.show_chart_outlined, type: TextInputType.number),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('ENREGISTRER', style: TextStyle(letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Reusable small widgets ───────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 10),
          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        const SizedBox(width: 2),
        Container(width: 3, height: 14, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 0.5)),
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType type;
  final bool required;

  const _Field(this.ctrl, this.label, this.icon, {
    this.type = TextInputType.text,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: required ? (v) => v == null || v.isEmpty ? 'Requis' : null : null,
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _MenuRow({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: color ?? AppColors.textSecondary),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(color: color)),
    ]);
  }
}