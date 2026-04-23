import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/models.dart';
import '../shared/widgets/shared_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// StaffScreen — tabbed layout so Commerciaux and Opérateurs are always
// reachable with a single tap, regardless of list length.
// ─────────────────────────────────────────────────────────────────────────────
class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffProvider);

    return staffAsync.when(
      loading: () => const Scaffold(body: AppLoading()),
      error: (e, stackTrace) =>
          Scaffold(body: Center(child: Text('Erreur: $e - $stackTrace'))),
      data: (staff) {
        final commercials =
        staff.where((s) => s.role == AppConstants.roleCommercial).toList();
        final operators =
        staff.where((s) => s.role == AppConstants.roleOperator).toList();

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            // ── AppBar with integrated TabBar ──────────────────────────────
            appBar: AppBar(
              // Remove default elevation so the tab indicator is flush
              scrolledUnderElevation: 0,
              bottom: TabBar(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                tabs: [
                  Tab(
                    icon: const Icon(Icons.business_center_outlined, size: 18),
                    text: 'Commerciaux (${commercials.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.engineering_outlined, size: 18),
                    text: 'Opérateurs (${operators.length})',
                  ),
                ],
                indicatorColor: AppColors.accent,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),

            // ── Two independent, scrollable tab views ─────────────────────
            body: TabBarView(
              children: [
                _StaffTab(
                  staffList: commercials,
                  emptyMessage: 'Aucun commercial enregistré',
                  emptyIcon: Icons.business_center_outlined,
                  onRefresh: () async => ref.invalidate(staffProvider),
                ),
                _StaffTab(
                  staffList: operators,
                  emptyMessage: 'Aucun opérateur enregistré',
                  emptyIcon: Icons.engineering_outlined,
                  onRefresh: () async => ref.invalidate(staffProvider),
                ),
              ],
            ),

            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _showCreateStaffDialog(context, ref),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Ajouter'),
            ),
          ),
        );
      },
    );
  }

  void _showCreateStaffDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(child: _CreateEditStaffDialog()),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StaffTab — tab content with a sticky search bar + pull-to-refresh list
// ─────────────────────────────────────────────────────────────────────────────
class _StaffTab extends StatefulWidget {
  final List<CommercialModel> staffList;
  final String emptyMessage;
  final IconData emptyIcon;
  final Future<void> Function() onRefresh;

  const _StaffTab({
    required this.staffList,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.onRefresh,
  });

  @override
  State<_StaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends State<_StaffTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<CommercialModel> get _filtered {
    if (_query.isEmpty) return widget.staffList;
    final q = _query.toLowerCase();
    return widget.staffList.where((s) {
      return s.fullName.toLowerCase().contains(q) ||
          s.firstname.toLowerCase().contains(q) ||
          s.name.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Column(
      children: [
        // ── Search bar ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: InputDecoration(
              hintText: 'Rechercher par nom…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
                },
              )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
            ),
          ),
        ),

        // ── List or empty states ────────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: filtered.isEmpty
                ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.45,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _query.isNotEmpty
                            ? Icons.search_off
                            : widget.emptyIcon,
                        size: 48,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _query.isNotEmpty
                            ? 'Aucun résultat pour "$_query"'
                            : widget.emptyMessage,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ],
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              itemCount: filtered.length,
              itemBuilder: (context, index) =>
                  _StaffCard(staff: filtered[index], index: index),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StaffCard — unchanged logic, kept as-is
// ─────────────────────────────────────────────────────────────────────────────
class _StaffCard extends ConsumerWidget {
  final CommercialModel staff;
  final int index;

  const _StaffCard({required this.staff, required this.index});

  Color get _roleColor => staff.role == AppConstants.roleCommercial
      ? AppColors.commercialColor
      : AppColors.operatorColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _roleColor.withOpacity(0.15),
          child: Text(
            staff.firstname.isNotEmpty
                ? staff.firstname[0].toUpperCase()
                : '?',
            style:
            TextStyle(color: _roleColor, fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(
          staff.fullName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(staff.email,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(staff.phone,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _roleColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border:
                    Border.all(color: _roleColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    staff.role == AppConstants.roleCommercial
                        ? 'Commercial'
                        : 'Opérateur',
                    style: TextStyle(
                        color: _roleColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 6),
                _CallButton(phone: staff.phone),
              ],
            ),
            PopupMenuButton<String>(
              color: AppColors.card,
              icon: const Icon(Icons.more_vert,
                  color: AppColors.textSecondary, size: 20),
              onSelected: (value) async {
                if (value == 'edit') {
                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => Dialog(
                      child: _CreateEditStaffDialog(staffToEdit: staff),
                    ),
                  );
                } else if (value == 'delete') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    barrierDismissible: true,
                    builder: (dialogContext) => AlertDialog(
                      backgroundColor: AppColors.card,
                      title: const Text('Confirmer la suppression'),
                      content: Text('Supprimer ${staff.fullName} ?'),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text('Annuler'),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: const Text('Supprimer',
                              style:
                              TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && context.mounted) {
                    try {
                      await ref
                          .read(firestoreRepoProvider)
                          .deleteStaff(staff.id);
                      ref.invalidate(staffProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                              Text('Personnel supprimé avec succès')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Erreur lors de la suppression: $e')),
                        );
                      }
                    }
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Modifier'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline,
                        size: 18, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Supprimer',
                        style: TextStyle(color: AppColors.error)),
                  ]),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    )
        .animate(
        delay: Duration(milliseconds: 50 * index))
        .fadeIn(duration: 400.ms)
        .slideX(begin: 0.1, end: 0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CreateEditStaffDialog — unchanged
// ─────────────────────────────────────────────────────────────────────────────
class _CreateEditStaffDialog extends ConsumerStatefulWidget {
  final CommercialModel? staffToEdit;

  const _CreateEditStaffDialog({this.staffToEdit});

  @override
  ConsumerState<_CreateEditStaffDialog> createState() =>
      _CreateEditStaffDialogState();
}

class _CreateEditStaffDialogState
    extends ConsumerState<_CreateEditStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstnameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  late String _role;
  bool _loading = false;
  String? _error;
  bool _isEditing = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.staffToEdit != null;

    if (_isEditing) {
      _firstnameCtrl.text = widget.staffToEdit!.firstname;
      _nameCtrl.text = widget.staffToEdit!.name;
      _emailCtrl.text = widget.staffToEdit!.email;
      _phoneCtrl.text = widget.staffToEdit!.phone;
      _addressCtrl.text = widget.staffToEdit!.address;
      _passwordCtrl.text = widget.staffToEdit!.password;
      _role = widget.staffToEdit!.role!;
    } else {
      _role = AppConstants.roleCommercial;
    }
  }

  @override
  void dispose() {
    _firstnameCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isEditing) {
        final updatedStaff = widget.staffToEdit!.copyWith(
          firstname: _firstnameCtrl.text,
          name: _nameCtrl.text,
          email: _emailCtrl.text,
          phone: _phoneCtrl.text,
          address: _addressCtrl.text,
          role: _role,
        );

        if (_passwordCtrl.text.isNotEmpty) {
          await ref.read(authServiceProvider).updateStaffPassword(
              widget.staffToEdit!, _passwordCtrl.text);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Personnel modifié avec succès')),
          );
        }
      } else {
        await ref.read(authServiceProvider).createStaffAccount(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
          role: _role,
          firstname: _firstnameCtrl.text,
          name: _nameCtrl.text,
          phone: _phoneCtrl.text,
          address: _addressCtrl.text,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Personnel créé avec succès')),
          );
        }
      }

      ref.invalidate(staffProvider);

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'Modifier le compte' : 'Créer un compte',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: AppConstants.roleCommercial,
                    label: Text('Commercial'),
                    icon: Icon(Icons.business_center_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: AppConstants.roleOperator,
                    label: Text('Opérateur'),
                    icon: Icon(Icons.engineering_outlined, size: 16),
                  ),
                ],
                selected: {_role},
                onSelectionChanged:
                _isEditing ? null : (s) => setState(() => _role = s.first),
                style: ButtonStyle(
                  backgroundColor:
                  MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.selected)) {
                      return AppColors.accent;
                    }
                    return AppColors.primaryLight;
                  }),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: _buildTextField(
                        _firstnameCtrl, 'Prénom', Icons.person_outline)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildTextField(
                        _nameCtrl, 'Nom', Icons.person_outline)),
              ]),
              const SizedBox(height: 12),
              _buildTextField(_emailCtrl, 'Email', Icons.email_outlined,
                  enabled: !_isEditing),
              const SizedBox(height: 12),
              _buildTextField(
                _passwordCtrl,
                _isEditing ? 'Nouveau mot de passe' : 'Mot de passe',
                Icons.lock_outlined,
                obscure: _obscurePassword,
                required: !_isEditing,
                onToggleObscure: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                  _phoneCtrl, 'Téléphone', Icons.phone_outlined,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _buildTextField(
                  _addressCtrl, 'Adresse', Icons.location_on_outlined),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 12)),
              ],
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      if (mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _save,
                    child: _loading
                        ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                        : Text(_isEditing ? 'Modifier' : 'Créer'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController ctrl,
      String label,
      IconData icon, {
        bool obscure = false,
        bool enabled = true,
        bool required = true,
        TextInputType keyboardType = TextInputType.text,
        VoidCallback? onToggleObscure,
      }) {
    final isPhone = keyboardType == TextInputType.phone;

    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: isPhone ? [_MoroccoPhoneFormatter()] : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: onToggleObscure != null
            ? IconButton(
          icon: Icon(
              obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggleObscure,
        )
            : null,
      ),
      validator: required
          ? (v) => v == null || v.isEmpty ? 'Requis' : null
          : isPhone
          ? (v) {
        if (v == null || v.isEmpty) return null;
        final digits = v.replaceAll(RegExp(r'[^\d]'), '');
        if (digits.length != 12) {
          return 'Numéro invalide (+212 XXXXXXXXX)';
        }
        return null;
      }
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers — unchanged
// ─────────────────────────────────────────────────────────────────────────────
class _MoroccoPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String digits =
    newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.startsWith('212')) digits = digits.substring(3);
    if (digits.startsWith('0')) digits = digits.substring(1);
    if (digits.length > 9) digits = digits.substring(0, 9);

    final buffer = StringBuffer('+212 ');
    for (int i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6) buffer.write('-');
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CallButton — animated pill button that launches a phone call
// ─────────────────────────────────────────────────────────────────────────────
class _CallButton extends StatefulWidget {
  final String phone;
  const _CallButton({required this.phone});

  @override
  State<_CallButton> createState() => _CallButtonState();
}

class _CallButtonState extends State<_CallButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  static const _green = Color(0xFF22C55E);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (widget.phone.isEmpty) return;
    await _ctrl.forward();
    await _ctrl.reverse();
    callPhone(widget.phone);
  }

  @override
  Widget build(BuildContext context) {
    final canCall = widget.phone.isNotEmpty;

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: canCall ? _onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: canCall
                ? const LinearGradient(
              colors: [Color(0xFF16A34A), _green],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : null,
            color: canCall ? null : AppColors.primaryLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.phone_rounded,
                size: 13,
                color: canCall ? Colors.white : AppColors.textMuted,
              ),
              const SizedBox(width: 5),
              Text(
                canCall ? 'Appeler' : 'N/A',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: canCall ? Colors.white : AppColors.textMuted,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}