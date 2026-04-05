import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';

// ─── Phone call helper (shared across all screens) ───────────────────────────

Future<void> callPhone(String phone) async {
  if (phone.isEmpty) return;
  final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

Widget phoneButton(String phone, {double size = 18}) {
  if (phone.isEmpty) return const SizedBox.shrink();
  return GestureDetector(
    onTap: () => callPhone(phone),
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.statusDelivered.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.statusDelivered.withOpacity(0.3)),
      ),
      child: Icon(Icons.phone_outlined, size: size, color: AppColors.statusDelivered),
    ),
  );
}

// ─── Status Badge ─────────────────────────────────────────────────────────────

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  Color get _color {
    switch (status) {
      case AppConstants.statusPending:    return AppColors.statusPending;
      case AppConstants.statusInProgress: return AppColors.statusInProgress;
      case AppConstants.statusDelivered:  return AppColors.statusDelivered;
      case AppConstants.statusCanceled:   return AppColors.statusCanceled;
      default: return AppColors.textMuted;
    }
  }

  String get _label {
    switch (status) {
      case AppConstants.statusPending:    return 'En attente';
      case AppConstants.statusInProgress: return 'En cours';
      case AppConstants.statusDelivered:  return 'Livré';
      case AppConstants.statusCanceled:   return 'Annulé';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withOpacity(0.4)),
      ),
      child: Text(
        _label,
        style: TextStyle(
            color: _color, fontSize: 11, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ─── Order Card ───────────────────────────────────────────────────────────────

class OrderCard extends StatelessWidget {
  final OrderModel order;
  final String? clientName;
  final String? commercialName;
  final VoidCallback? onTap;
  final Widget? trailing;

  const OrderCard({
    super.key,
    required this.order,
    this.clientName,
    this.commercialName,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: ID + status + trailing
              Row(
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#${order.orderId}',
                      style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.8),
                    ),
                  ),
                  const SizedBox(width: 7),
                  StatusBadge(status: order.status),
                  const Spacer(),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 10),

              // Client + chantier
              Row(children: [
                Expanded(
                  child: _InfoChip(
                      icon: Icons.person_outline,
                      label: clientName ?? order.clientId),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InfoChip(
                      icon: Icons.location_on_outlined, label: order.chantier),
                ),
              ]),
              const SizedBox(height: 6),

              // Béton + quantity
              Row(children: [
                Expanded(
                  child: _InfoChip(
                      icon: Icons.inventory_2_outlined, label: order.beton),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InfoChip(
                    icon: Icons.scale_outlined,
                    label: '${order.qteDemande} m³',
                    color: AppColors.accentGold,
                  ),
                ),
              ]),
              const SizedBox(height: 6),

              // Date + commercial
              Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      fmt.format(order.createdAt),
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (commercialName != null) ...[
                    const Spacer(),
                    const Icon(Icons.badge_outlined,
                        size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        commercialName!,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color ?? AppColors.textSecondary),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 11,
                  color: color ?? AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final int animIndex;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.animIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: 11),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 100 * animIndex))
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.2, end: 0, curve: Curves.easeOut);
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const SectionHeader({super.key, required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis),
        ),
        if (action != null) action!,
      ],
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyState(
      {super.key,
        required this.message,
        this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: AppColors.textMuted.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Loading ──────────────────────────────────────────────────────────────────

class AppLoading extends StatelessWidget {
  const AppLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
        child: CircularProgressIndicator(color: AppColors.accent));
  }
}
