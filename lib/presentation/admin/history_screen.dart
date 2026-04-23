import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(allHistoryProvider);

    return Scaffold(
      body: SafeArea(
        child: historyAsync.when(
          loading: () => const AppLoading(),
          // error: (e, _) => Center(child: Text('Erreur: $e')),
          data: (history) {
            if (history.isEmpty) {
              return const EmptyState(
                message: 'Aucun historique de modification',
                icon: Icons.history_outlined,
              );
            }
            return Column(
              children: [
                // Download button
                Container(
                  color: AppColors.primaryLight,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        '${history.length} modification(s)',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => _downloadLogs(context, history),
                        icon: const Icon(Icons.download_outlined, size: 18),
                        label: const Text('Télécharger PDF'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: history.length,
                    itemBuilder: (ctx, i) => _HistoryCard(entry: history[i]),
                  ),
                ),
              ],
            );
          }, error: (Object error, StackTrace stackTrace) {
            if (kDebugMode) {
              print('$error');
            }
            return Text('erreur : $error');
        },
        ),
      ),
    );
  }

  Future<void> _downloadLogs(BuildContext context, List<OrderHistoryModel> history) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        pw.Header(level: 0, child: pw.Text('Historique des modifications - Mazabeton',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 16),
        ...history.map((h) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 12),
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(h.commercialName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(dateFormat.format(h.modifiedAt), style: const pw.TextStyle(color: PdfColors.grey)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text('Modifications:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
              ...h.newData.entries.map((e) => pw.Text(
                '  ${translate(e.key)}:  ${e.key == 'deliveryDate' ? _formatDate(h.oldData[e.key]) : h.oldData[e.key] ?? '-'} -> ${e.key == 'deliveryDate'? _formatDate(e.value) : e.value}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              )),
            ],
          ),
        )),
      ],
    ));

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Mazabeton_logs.pdf');
  }
}

class _HistoryCard extends StatelessWidget {
  final OrderHistoryModel entry;

  const _HistoryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd/MM/yyyy HH:mm');
    final changes = entry.newData.entries
        .where((e) => entry.oldData[e.key]?.toString() != e.value?.toString())
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.accent.withOpacity(0.15),
                  child: Text(
                    entry.commercialName.isNotEmpty ? entry.commercialName[0]
                        .toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.commercialName, style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(
                        formatter.format(entry.modifiedAt),
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppColors.accentLight.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${changes.length} modif.',
                    style: const TextStyle(color: AppColors.accentLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (changes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              ...changes.map((e) =>
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: e.key!= 'betonId' ?  Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 12),
                              children: [
                                TextSpan(
                                  text: '${translate(e.key)}: ',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary),
                                ),
                                TextSpan(
                                  text: e.key == 'deliveryDate'
                                      ? _formatDate(entry.oldData[e.key])
                                      : '${entry.oldData[e.key] ?? '-'}',
                                  style: const TextStyle(
                                    color: AppColors.statusCanceled,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const TextSpan(
                                  text: ' → ',
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                                TextSpan(
                                  text:  e.key == 'deliveryDate'
                                      ? _formatDate(e.value) : '${e.value}',
                                  style: const TextStyle(
                                      color: AppColors.statusDelivered),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ) : SizedBox(),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '-';

    try {
      // If it's a Firestore Timestamp
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return DateFormat('dd/mm/yyyy').format(date); // or any format you prefer
      }
      // If it's a DateTime object
      else if (timestamp is DateTime) {
        return DateFormat('dd/mm/yyyy').format(timestamp);
      }
      // If it's a string
      else if (timestamp is String) {
        return timestamp;
      }
    } catch (e) {
      return timestamp.toString();
    }

    return '-';
  }

  String translate(key){
   switch(key) {
     case 'deliveryDate' : return 'Date de Livraison'; break;
     case 'qteDemande' : return 'Quantité Demandée'; break;
     case 'beton' : return 'Béton'; break;
     case 'betonPrice' : return 'Prix de Béton'; break;
     default : return key;
  }
}
