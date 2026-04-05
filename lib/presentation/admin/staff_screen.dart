import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/models.dart';
import '../shared/widgets/shared_widgets.dart';

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffProvider);

    return Scaffold(
      body: staffAsync.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (staff) {
          final commercials = staff.where((s) => s.role == AppConstants.roleCommercial).toList();
          final operators = staff.where((s) => s.role == AppConstants.roleOperator).toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(staffProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionHeader(title: 'Commerciaux (${commercials.length})'),
                const SizedBox(height: 12),
                ...commercials.asMap().entries.map((e) => _StaffCard(
                  staff: e.value,
                  index: e.key,
                )),
                const SizedBox(height: 24),
                SectionHeader(title: 'Opérateurs (${operators.length})'),
                const SizedBox(height: 12),
                ...operators.asMap().entries.map((e) => _StaffCard(
                  staff: e.value,
                  index: e.key + commercials.length,
                )),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateStaffDialog(context, ref),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Ajouter'),
      ),
    );
  }

  void _showCreateStaffDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        child: _CreateEditStaffDialog(),
      ),
    );
  }
}

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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _roleColor.withOpacity(0.15),
          child: Text(
            staff.firstname.isNotEmpty ? staff.firstname[0].toUpperCase() : '?',
            style: TextStyle(color: _roleColor, fontWeight: FontWeight.w700),
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
            Text(staff.email, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(staff.phone, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _roleColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _roleColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    staff.role == AppConstants.roleCommercial ? 'Commercial' : 'Opérateur',
                    style: TextStyle(color: _roleColor, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(height: 2,),
                phoneButton(staff.phone)
              ],
            ),
            PopupMenuButton<String>(
              color: AppColors.card,
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
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
                  // Use showDialog with proper context
                  final confirm = await showDialog<bool>(
                    context: context,
                    barrierDismissible: true,
                    builder: (dialogContext) => AlertDialog(
                      backgroundColor: AppColors.card,
                      title: const Text('Confirmer la suppression'),
                      content: Text('Supprimer ${staff.fullName} ?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(false),
                            child: const Text('Annuler')
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          child: const Text('Supprimer', style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && context.mounted) {
                    try {
                      await ref.read(firestoreRepoProvider).deleteStaff(staff.id);
                      ref.invalidate(staffProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Personnel supprimé avec succès')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur lors de la suppression: $e')),
                        );
                      }
                    }
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Modifier')
                        ]
                    )
                ),
                const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                          SizedBox(width: 8),
                          Text('Supprimer', style: TextStyle(color: AppColors.error))
                        ]
                    )
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    ).animate(delay: Duration(milliseconds: 50 * index)).fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0);
  }
}

class _CreateEditStaffDialog extends ConsumerStatefulWidget {
  final CommercialModel? staffToEdit;

  const _CreateEditStaffDialog({this.staffToEdit});

  @override
  ConsumerState<_CreateEditStaffDialog> createState() => _CreateEditStaffDialogState();
}

class _CreateEditStaffDialogState extends ConsumerState<_CreateEditStaffDialog> {
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

  @override
  void initState() {
    super.initState();
    _isEditing = widget.staffToEdit != null;

    if (_isEditing) {
      // Pre-fill form with existing data
      _firstnameCtrl.text = widget.staffToEdit!.firstname;
      _nameCtrl.text = widget.staffToEdit!.name;
      _emailCtrl.text = widget.staffToEdit!.email;
      _phoneCtrl.text = widget.staffToEdit!.phone;
      _addressCtrl.text = widget.staffToEdit!.address;
      _passwordCtrl.text = widget.staffToEdit!.password;
      _role = widget.staffToEdit!.role;
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
        // Update existing staff
        final updatedStaff = widget.staffToEdit!.copyWith(
          firstname: _firstnameCtrl.text,
          name: _nameCtrl.text,
          email: _emailCtrl.text,
          phone: _phoneCtrl.text,
          address: _addressCtrl.text,
          role: _role,
        );

        // await ref.read(firestoreRepoProvider).updateStaff(updatedStaff);

        // If password is provided, update it in Auth
        // Todo : create this method to update the staff password
        if (_passwordCtrl.text.isNotEmpty) {
          await ref.read(authServiceProvider).updateStaffPassword(
              widget.staffToEdit!,
              _passwordCtrl.text
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Personnel modifié avec succès')),
          );
        }
      } else {
        // Create new staff
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

      // Refresh the staff list
      ref.invalidate(staffProvider);

      if (mounted) {
        // Use Navigator.of(context).pop() with explicit context
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() {
        _loading = false;
      });
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
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              // Role selector (disabled when editing)
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: AppConstants.roleCommercial,
                      label: Text('Commercial'),
                      icon: Icon(Icons.business_center_outlined, size: 16)
                  ),
                  ButtonSegment(
                      value: AppConstants.roleOperator,
                      label: Text('Opérateur'),
                      icon: Icon(Icons.engineering_outlined, size: 16)
                  ),
                ],
                selected: {_role},
                onSelectionChanged: _isEditing ? null : (s) => setState(() => _role = s.first),
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.selected)) return AppColors.accent;
                    return AppColors.primaryLight;
                  }),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _buildTextField(_firstnameCtrl, 'Prénom', Icons.person_outline)),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField(_nameCtrl, 'Nom', Icons.person_outline)),
              ]),
              const SizedBox(height: 12),
              _buildTextField(_emailCtrl, 'Email', Icons.email_outlined, enabled: !_isEditing),
              const SizedBox(height: 12),
              _buildTextField(
                _passwordCtrl,
                _isEditing ? 'Nouveau mot de passe' : 'Mot de passe',
                Icons.lock_outlined,
                obscure: true,
                required: !_isEditing,
              ),
              const SizedBox(height: 12),
              _buildTextField(_phoneCtrl, 'Téléphone', Icons.phone_outlined),
              const SizedBox(height: 12),
              _buildTextField(_addressCtrl, 'Adresse', Icons.location_on_outlined),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
              ],
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _save,
                    child: _loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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
      }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: required ? (v) => v == null || v.isEmpty ? 'Requis' : null : null,
    );
  }
}