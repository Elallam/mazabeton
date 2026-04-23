import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../widgets/shared_widgets.dart';

class OrderDetailDialog extends StatelessWidget {
  final OrderModel order;
  final String clientName;

  const OrderDetailDialog({super.key, required this.order, required this.clientName});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd/MM/yyyy HH:mm');

    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#${order.orderId}',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                StatusBadge(status: order.status),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            _DetailRow(label: 'Client', value: clientName, icon: Icons.person_outline),
            _DetailRow(label: 'Chantier', value: order.chantier, icon: Icons.location_on_outlined),
            _DetailRow(label: 'Béton', value: order.beton, icon: Icons.inventory_2_outlined),
            _DetailRow(label: 'Prix béton', value: '${order.betonPrice} DH/ton', icon: Icons.price_change_outlined),
            _DetailRow(label: 'Contact', value: order.contact, icon: Icons.contact_phone_outlined),
            GestureDetector(
                onTap: order.contactPhone.isNotEmpty ? () => callPhone(order.contactPhone) : null,
                child: _InfoChip(icon: Icons.phone_outlined, label: order.contactPhone, tappable: order.contactPhone.isNotEmpty),
              ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _QuantityBox(
                    label: 'Demandé',
                    value: '${order.qteDemande} ton',
                    color: AppColors.statusPending,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuantityBox(
                    label: 'Livré',
                    value: '${order.qteLivre} ton',
                    color: AppColors.statusDelivered,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuantityBox(
                    label: 'Supplément',
                    value: '${order.supplement} ton',
                    color: AppColors.accentLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailRow(
              label: 'Créé le',
              value: formatter.format(order.createdAt),
              icon: Icons.calendar_today_outlined,
            ),
            if (order.deliveryDate != null)
              _DetailRow(
                label: 'Livraison prévue',
                value: formatter.format(order.deliveryDate!),
                icon: Icons.local_shipping_outlined,
              ),
            // _DetailRow(
            //   label: 'Payé',
            //   value: order.soldPaid ? 'Oui' : 'Non',
            //   icon: Icons.payment_outlined,
            //   valueColor: order.soldPaid ? AppColors.statusDelivered : AppColors.statusCanceled,
            // ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, required this.icon, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _QuantityBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
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

