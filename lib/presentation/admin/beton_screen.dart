import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../shared/widgets/shared_widgets.dart';

// Category color map
const _categoryColors = {
  'Courant':     AppColors.accent,
  'Spécial':     AppColors.accentOrange,
  'Haute Perf.': AppColors.accentGold,
  'Structurel':  AppColors.statusInProgress,
  'Léger':       AppColors.statusDelivered,
  'Autre':       AppColors.textMuted,
};

Color _colorForCategory(String cat) =>
    _categoryColors[cat] ?? AppColors.textSecondary;

class BetonsScreen extends ConsumerStatefulWidget {
  const BetonsScreen({super.key});

  @override
  ConsumerState<BetonsScreen> createState() => _BetonsScreenState();
}

class _BetonsScreenState extends ConsumerState<BetonsScreen>
    with SingleTickerProviderStateMixin {
  String _search = '';
  String? _selectedCategory;
  late TabController _tabController;

  static const _tabs = ['Tous', 'Courant', 'Spécial', 'Haute Perf.', 'Structurel', 'Autre'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedCategory = _tabController.index == 0 ? null : _tabs[_tabController.index];
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final betonsAsync = ref.watch(betonsProvider);

    return Scaffold(
      body: Column(
        children: [
          // Search + tabs
          Container(
            color: AppColors.primaryLight,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v.toLowerCase()),
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un béton...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tabAlignment: TabAlignment.start,
                  tabs: _tabs.map((t) => Tab(text: t)).toList(),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: betonsAsync.when(
              loading: () => const AppLoading(),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (betons) {
                var filtered = betons.where((b) {
                  final matchSearch = _search.isEmpty ||
                      b.name.toLowerCase().contains(_search) ||
                      b.category.toLowerCase().contains(_search);
                  final matchCat = _selectedCategory == null || b.category == _selectedCategory;
                  return matchSearch && matchCat;
                }).toList();

                // Group by category
                final grouped = <String, List<BetonModel>>{};
                for (final b in filtered) {
                  grouped.putIfAbsent(b.category.isEmpty ? 'Autre' : b.category, () => []).add(b);
                }

                if (filtered.isEmpty) {
                  return const EmptyState(
                    message: 'Aucun type de béton trouvé',
                    icon: Icons.inventory_2_outlined,
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Summary stat
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined, color: AppColors.accent, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            '${filtered.length} type(s) de béton',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const Spacer(),
                          Text(
                            '${grouped.length} catégorie(s)',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                    // Grouped list
                    ...grouped.entries.toList().asMap().entries.map((entry) {
                      final idx = entry.key;
                      final cat = entry.value.key;
                      final items = entry.value.value;
                      final color = _colorForCategory(cat);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (idx > 0) const SizedBox(height: 8),
                          // Category header
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  cat,
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${items.length}',
                                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...items.asMap().entries.map((e) => _BetonCard(
                            beton: e.value,
                            index: idx * 10 + e.key,
                            categoryColor: color,
                          )),
                          const SizedBox(height: 8),
                        ],
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBetonForm(context, null),
        icon: const Icon(Icons.add_outlined),
        label: const Text('Nouveau béton'),
      ),
    );
  }

  void _showBetonForm(BuildContext context, BetonModel? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BetonFormSheet(existing: existing),
    );
  }
}

// ─── Béton Card ───────────────────────────────────────────────────────────────

class _BetonCard extends ConsumerWidget {
  final BetonModel beton;
  final int index;
  final Color categoryColor;

  const _BetonCard({
    required this.beton,
    required this.index,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: categoryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: categoryColor.withOpacity(0.3)),
          ),
          child: Center(
            child: Text(
              beton.name.length >= 2 ? beton.name.substring(0, 2) : beton.name,
              style: TextStyle(
                color: categoryColor,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
        title: Text(beton.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          beton.category.isEmpty ? 'Sans catégorie' : beton.category,
          style: TextStyle(color: categoryColor.withOpacity(0.8), fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.price_change_outlined, size: 20, color: AppColors.accentGold),
              tooltip: 'Prix par client',
              onPressed: () => _showPricingSheet(context),
            ),
            PopupMenuButton<String>(
              color: AppColors.card,
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
              onSelected: (v) => _handleMenu(context, ref, v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: _MenuRow(icon: Icons.edit_outlined, label: 'Modifier')),
                const PopupMenuItem(
                  value: 'delete',
                  child: _MenuRow(icon: Icons.delete_outline, label: 'Supprimer', color: AppColors.error),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: 30 * index)).fadeIn(duration: 350.ms).slideX(begin: 0.05, end: 0);
  }

  void _handleMenu(BuildContext context, WidgetRef ref, String value) async {
    if (value == 'edit') {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => _BetonFormSheet(existing: beton),
      );
    } else if (value == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Supprimer le béton'),
          content: Text('Supprimer "${beton.name}" ? Les commandes existantes ne seront pas affectées.'),
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
        await ref.read(firestoreRepoProvider).deleteBeton(beton.id);
      }
    }
  }

  void _showPricingSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _BetonPricingSheet(beton: beton),
    );
  }
}

// ─── Béton Form Sheet ─────────────────────────────────────────────────────────

class _BetonFormSheet extends ConsumerStatefulWidget {
  final BetonModel? existing;
  const _BetonFormSheet({this.existing});

  @override
  ConsumerState<_BetonFormSheet> createState() => _BetonFormSheetState();
}

class _BetonFormSheetState extends ConsumerState<_BetonFormSheet> {
  final _nameCtrl = TextEditingController();
  String _category = 'Courant';
  bool _loading = false;

  static const _categories = ['Courant', 'Spécial', 'Haute Perf.', 'Structurel', 'Léger', 'Autre'];

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.existing?.name ?? '';
    _category = widget.existing?.category.isNotEmpty == true ? widget.existing!.category : 'Courant';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      if (widget.existing != null) {
        await ref.read(firestoreRepoProvider).updateBeton(widget.existing!.id, {
          'name': _nameCtrl.text.trim(),
          'category': _category,
        });
      } else {
        await ref.read(firestoreRepoProvider).createBeton(
          BetonModel(id: '', name: _nameCtrl.text.trim(), category: _category),
        );
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text(
            widget.existing != null ? 'Modifier le béton' : 'Nouveau type de béton',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),

          // Name
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nom du béton *',
              prefixIcon: Icon(Icons.inventory_2_outlined),
              hintText: 'Ex: B25, B30, FC30...',
            ),
          ),
          const SizedBox(height: 20),

          // Category picker
          const Text('Catégorie', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((cat) {
              final selected = _category == cat;
              final color = _colorForCategory(cat);
              return GestureDetector(
                onTap: () => setState(() => _category = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? color.withOpacity(0.2) : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? color : AppColors.divider,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: selected ? color : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text(
                widget.existing != null ? 'ENREGISTRER' : 'CRÉER',
                style: const TextStyle(letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Béton Pricing Sheet (per client/chantier) ────────────────────────────────

class _BetonPricingSheet extends ConsumerStatefulWidget {
  final BetonModel beton;
  const _BetonPricingSheet({required this.beton});

  @override
  ConsumerState<_BetonPricingSheet> createState() => _BetonPricingSheetState();
}

class _BetonPricingSheetState extends ConsumerState<_BetonPricingSheet> {
  ClientModel? _selectedClient;
  String? _selectedChantier;
  final _prixCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _prixCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedClient == null || _selectedChantier == null || _prixCtrl.text.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(firestoreRepoProvider).setBetonChantierPrice(
        BetonChantierModel(
          id: '',
          betonId: widget.beton.id,
          chantier: _selectedChantier!,
          clientId: _selectedClient!.id,
          prix: double.tryParse(_prixCtrl.text) ?? 0,
        ),
      );
      _prixCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prix enregistré !'), backgroundColor: AppColors.statusDelivered),
        );
        setState(() { _selectedClient = null; _selectedChantier = null; });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final clientsAsync = ref.watch(clientsProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _colorForCategory(widget.beton.category).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _colorForCategory(widget.beton.category).withOpacity(0.4)),
                  ),
                  child: Text(widget.beton.name,
                      style: TextStyle(color: _colorForCategory(widget.beton.category), fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                const Text('— Prix par client', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 20),

            // Client picker
            clientsAsync.when(
              loading: () => const AppLoading(),
              error: (_, __) => const SizedBox.shrink(),
              data: (clients) => DropdownButtonFormField<ClientModel>(
                value: _selectedClient,
                dropdownColor: AppColors.card,
                decoration: const InputDecoration(
                  labelText: 'Client',
                  prefixIcon: Icon(Icons.person_outline),
                  isDense: true,
                ),
                items: clients.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text('${c.fullName} (${c.company})'),
                )).toList(),
                onChanged: (c) => setState(() {
                  _selectedClient = c;
                  _selectedChantier = null;
                }),
              ),
            ),
            const SizedBox(height: 12),

            // Chantier picker
            if (_selectedClient != null)
              DropdownButtonFormField<String>(
                value: _selectedChantier,
                dropdownColor: AppColors.card,
                decoration: const InputDecoration(
                  labelText: 'Chantier',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  isDense: true,
                ),
                items: _selectedClient!.chantiers
                    .map((ch) => DropdownMenuItem(value: ch, child: Text(ch)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedChantier = v),
              ),
            const SizedBox(height: 12),

            // Price input
            TextField(
              controller: _prixCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Prix (DH/ton)',
                prefixIcon: Icon(Icons.price_change_outlined),
                suffixText: 'DH/ton',
                isDense: true,
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: (_saving || _selectedClient == null || _selectedChantier == null)
                    ? null
                    : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('ENREGISTRER LE PRIX', style: TextStyle(letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
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