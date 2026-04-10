import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../../core/constants/app_constants.dart';

/// Thrown when an order would push plafondFake above the allowed ceiling.
class PlafondException implements Exception {
  final String message;
  final double plafond;
  final double plafondFake;
  final double orderCost;
  final double tolerance;

  const PlafondException({
    required this.message,
    required this.plafond,
    required this.plafondFake,
    required this.orderCost,
    required this.tolerance,
  });

  @override
  String toString() => message;
}

class FirestoreRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Clients ────────────────────────────────────────────────────────────────

  Stream<List<ClientModel>> watchClients() {
    return _db
        .collection(AppConstants.clientsCollection)
        .where('delete', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => ClientModel.fromMap(d.data(), d.id))
        .toList());
  }

  Future<ClientModel?> getClient(String clientId) async {
    final doc = await _db.collection(AppConstants.clientsCollection).doc(clientId).get();
    if (!doc.exists) return null;
    return ClientModel.fromMap(doc.data()!, doc.id);
  }

  Future<String> createClient(ClientModel client) async {
    final ref = _db.collection(AppConstants.clientsCollection).doc();
    await ref.set(client.toMap());
    return ref.id;
  }

  Future<void> updateClient(String clientId, Map<String, dynamic> data) async {
    await _db.collection(AppConstants.clientsCollection).doc(clientId).update(data);
  }

  /// Soft-delete: sets delete=true so existing orders still reference the client
  Future<void> softDeleteClient(String clientId) async {
    await _db
        .collection(AppConstants.clientsCollection)
        .doc(clientId)
        .update({'delete': true});
  }

  Future<void> toggleClientBlock(String clientId, bool blocked) async {
    await _db
        .collection(AppConstants.clientsCollection)
        .doc(clientId)
        .update({'isBlocked': blocked});
  }

  // ─── Betons ─────────────────────────────────────────────────────────────────

  Future<List<BetonModel>> getBetons() async {
    final snap = await _db
        .collection(AppConstants.betonsCollection)
        .doc(AppConstants.betonDocId)
        .collection('types')
        .get();
    return snap.docs.map((d) => BetonModel.fromMap(d.data(), d.id)).toList();
  }

  Stream<List<BetonModel>> watchBetons() {
    return _db
        .collection(AppConstants.betonsCollection)
        .doc(AppConstants.betonDocId)
        .collection('types')
        .orderBy('category')
        .snapshots()
        .map((s) => s.docs.map((d) => BetonModel.fromMap(d.data(), d.id)).toList());
  }

  Future<String> createBeton(BetonModel beton) async {
    final ref = _db
        .collection(AppConstants.betonsCollection)
        .doc(AppConstants.betonDocId)
        .collection('types')
        .doc();
    await ref.set(beton.toMap());
    return ref.id;
  }

  Future<void> updateBeton(String betonId, Map<String, dynamic> data) async {
    await _db
        .collection(AppConstants.betonsCollection)
        .doc(AppConstants.betonDocId)
        .collection('types')
        .doc(betonId)
        .update(data);
  }

  Future<void> deleteBeton(String betonId) async {
    await _db
        .collection(AppConstants.betonsCollection)
        .doc(AppConstants.betonDocId)
        .collection('types')
        .doc(betonId)
        .delete();
  }

  // ─── BetonChantier ──────────────────────────────────────────────────────────

  // All betonChantier for a client (admin manager)
  Stream<List<BetonChantierModel>> watchBetonChantiers(String clientId) {
    return _db
        .collection(AppConstants.betonChantierCollection)
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map((s) => s.docs.map((d) => BetonChantierModel.fromMap(d.data(), d.id)).toList());
  }

  // Reactive betons for a specific client x chantier (order form)
  Stream<List<BetonChantierModel>> watchBetonChantiersByChantier(String clientId, String chantier) {
    return _db
        .collection(AppConstants.betonChantierCollection)
        .where('clientId', isEqualTo: clientId)
        .where('chantier', isEqualTo: chantier)
        .snapshots()
        .map((s) => s.docs.map((d) => BetonChantierModel.fromMap(d.data(), d.id)).toList());
  }

  Future<List<BetonChantierModel>> getBetonChantiers(String clientId, String chantier) async {
    final snap = await _db
        .collection(AppConstants.betonChantierCollection)
        .where('clientId', isEqualTo: clientId)
        .where('chantier', isEqualTo: chantier)
        .get();
    return snap.docs.map((d) => BetonChantierModel.fromMap(d.data(), d.id)).toList();
  }

  // Upsert with composite key clientId_chantier_betonId
  Future<void> setBetonChantierPrice(BetonChantierModel bc) async {
    final id = '${bc.clientId}_${bc.chantier}_${bc.betonId}';
    await _db
        .collection(AppConstants.betonChantierCollection)
        .doc(id)
        .set({...bc.toMap(), 'id': id}, SetOptions(merge: true));
  }

  Future<void> deleteBetonChantier(String id) async {
    await _db.collection(AppConstants.betonChantierCollection).doc(id).delete();
  }

  // ─── Orders ─────────────────────────────────────────────────────────────────

  Stream<List<OrderModel>> watchActiveOrders() {
    return _db
        .collection(AppConstants.ordersCollection)
        .where('status', whereIn: [AppConstants.statusPending, AppConstants.statusInProgress])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => OrderModel.fromMap(d.data(), d.id)).toList());
  }

  Stream<List<OrderModel>> watchFinishedOrders() {
    return _db
        .collection(AppConstants.ordersCollection)
        .where('status', whereIn: [AppConstants.statusDelivered, AppConstants.statusCanceled])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => OrderModel.fromMap(d.data(), d.id)).toList());
  }

  Stream<List<OrderModel>> watchOrdersForCommercial(String commercialId) {
    return _db
        .collection(AppConstants.ordersCollection)
        .where('commercialId', isEqualTo: commercialId)
        .where('status', whereIn: [AppConstants.statusPending, AppConstants.statusInProgress])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => OrderModel.fromMap(d.data(), d.id)).toList());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PLAFOND LOGIC
  //
  // plafond          : hard ceiling — admin only, never touched here
  // plafondFake      : committed amount (orders in-flight)
  //                    += orderCost on CREATE
  //                    -= orderCost on CANCEL (reversal)
  //                    tolerance = 5 % of plafond (configurable below)
  // plafondDisponible: settled real balance
  //                    -= (qteLivre × prix) when status → delivered
  //                    re-adjusted when qteLivre changes on an already-delivered order
  // ─────────────────────────────────────────────────────────────────────────

  static const double _plafondTolerance = 0.05; // 5 %

  /// Throws a [PlafondException] if creating this order would push plafondFake
  /// above plafond + tolerance.
  Future<void> checkPlafondBeforeCreate({
    required String clientId,
    required double orderCost,
  }) async {
    final doc = await _db.collection(AppConstants.clientsCollection).doc(clientId).get();
    if (!doc.exists) throw Exception('Client introuvable');
    final data = doc.data()!;
    final plafond    = (data['plafond']     ?? 0).toDouble();
    final fake       = (data['plafondFake'] ?? 0).toDouble();
    final tolerance  = plafond * _plafondTolerance;
    final newFake    = fake + orderCost;
    if (newFake > plafond + tolerance) {
      throw PlafondException(
        message: 'Plafond dépassé. '
            'Engagé : ${fake.toStringAsFixed(0)} DH, '
            'Commande : ${orderCost.toStringAsFixed(0)} DH, '
            'Plafond max : ${(plafond + tolerance).toStringAsFixed(0)} DH.',
        plafond: plafond,
        plafondFake: fake,
        orderCost: orderCost,
        tolerance: tolerance,
      );
    }
  }

  /// Create order + atomically update plafondFake.
  Future<String> createOrder(OrderModel order) async {
    final orderRef = _db.collection(AppConstants.ordersCollection).doc();
    final clientRef = _db.collection(AppConstants.clientsCollection).doc(order.clientId);

    final orderCost = order.qteDemande * order.betonPrice;

    // Re-check inside transaction to avoid TOCTOU race
    return _db.runTransaction<String>((tx) async {
      final clientSnap = await tx.get(clientRef);
      if (!clientSnap.exists) throw Exception('Client introuvable');
      final data      = clientSnap.data()!;
      final plafond   = (data['plafond']     ?? 0).toDouble();
      final fake      = (data['plafondFake'] ?? 0).toDouble();
      final tolerance = plafond * _plafondTolerance;

      if (fake + orderCost > plafond + tolerance) {
        throw PlafondException(
          message: 'Plafond dépassé (transaction).',
          plafond: plafond, plafondFake: fake,
          orderCost: orderCost, tolerance: tolerance,
        );
      }

      final withId = OrderModel(
        id: orderRef.id,
        orderId: orderRef.id.substring(0, 8).toUpperCase(),
        beton: order.beton,
        betonId: order.betonId,
        betonPrice: order.betonPrice,
        chantier: order.chantier,
        clientId: order.clientId,
        commercialId: order.commercialId,
        contact: order.contact,
        contactPhone: order.contactPhone,
        createdAt: order.createdAt,
        deliveryDate: order.deliveryDate,
        qteDemande: order.qteDemande,
        qteLivre: order.qteLivre,
        soldPaid: order.soldPaid,
        status: order.status,
        supplement: order.supplement,
      );

      tx.set(orderRef, withId.toMap());
      // Commit plafondFake increase
      tx.update(clientRef, {
        'plafondFake': FieldValue.increment(orderCost),
      });

      return orderRef.id;
    });
  }

  /// Update order fields + atomically maintain plafondFake and plafondDisponible.
  ///
  /// Rules applied in a transaction:
  ///   • If status changes TO canceled  → reverse plafondFake by old orderCost
  ///   • If status changes FROM canceled → re-add plafondFake (re-opening)
  ///   • If status changes TO delivered  → decrease plafondDisponible by new qteLivre × prix
  ///   • If status was already delivered and qteLivre changed
  ///       → adjust plafondDisponible by delta (newQte - oldQte) × prix
  Future<void> updateOrder(
      String orderId,
      Map<String, dynamic> updates,
      OrderModel oldOrder,
      String commercialId,
      String commercialName,
      ) async {
    final orderRef  = _db.collection(AppConstants.ordersCollection).doc(orderId);
    final clientRef = _db.collection(AppConstants.clientsCollection).doc(oldOrder.clientId);
    final histRef   = orderRef.collection(AppConstants.orderHistoryCollection).doc();

    await _db.runTransaction((tx) async {
      final clientSnap = await tx.get(clientRef);
      if (!clientSnap.exists) return;

      final clientData      = clientSnap.data()!;
      final plafond         = (clientData['plafond']          ?? 0).toDouble();
      final currentFake     = (clientData['plafondFake']      ?? 0).toDouble();
      // ignore: unused_local_variable
      final currentDispo    = (clientData['plafondDisponible']?? 0).toDouble();
      final tolerance       = plafond * _plafondTolerance;

      final newStatus   = updates['status'] as String? ?? oldOrder.status;
      final oldStatus   = oldOrder.status;
      final prix        = oldOrder.betonPrice;
      final oldQte      = oldOrder.qteDemande;
      final newQteLivre = (updates['qteLivre'] as num?)?.toDouble() ?? oldOrder.qteLivre;
      final oldQteLivre = oldOrder.qteLivre;
      final oldCost     = oldQte * prix;

      double fakeDelta  = 0;
      double dispoDelta = 0;

      // ── plafondFake adjustments ────────────────────────────────────────
      final becomingCanceled  = newStatus == AppConstants.statusCanceled && oldStatus != AppConstants.statusCanceled;
      final restoredFromCancel= oldStatus == AppConstants.statusCanceled && newStatus != AppConstants.statusCanceled;

      if (becomingCanceled) {
        // Release commitment
        fakeDelta = -oldCost;
      } else if (restoredFromCancel) {
        // Re-validate tolerance before re-adding
        if (currentFake + oldCost > plafond + tolerance) {
          throw PlafondException(
            message: 'Impossible de rouvrir : plafond dépassé.',
            plafond: plafond, plafondFake: currentFake,
            orderCost: oldCost, tolerance: tolerance,
          );
        }
        fakeDelta = oldCost;
      }

      // ── plafondDisponible adjustments ──────────────────────────────────
      final becomingDelivered = newStatus == AppConstants.statusDelivered && oldStatus != AppConstants.statusDelivered;
      final wasAlreadyDelivered = oldStatus == AppConstants.statusDelivered && newStatus == AppConstants.statusDelivered;
      final leavingDelivered    = oldStatus == AppConstants.statusDelivered && newStatus != AppConstants.statusDelivered;

      if (becomingDelivered) {
        // Charge settled balance for delivered quantity
        dispoDelta = -(newQteLivre * prix);
      } else if (wasAlreadyDelivered && newQteLivre != oldQteLivre) {
        // Adjust for qty change on already-delivered order
        dispoDelta = -((newQteLivre - oldQteLivre) * prix);
      } else if (leavingDelivered) {
        // Reverse previous charge when un-delivering
        dispoDelta = oldQteLivre * prix;
      }

      // Apply updates
      tx.update(orderRef, updates);
      tx.set(histRef, {
        'oldData':        oldOrder.toMap(),
        'newData':        updates,
        'commercialId':   commercialId,
        'commercialName': commercialName,
        'modifiedAt':     FieldValue.serverTimestamp(),
      });

      // Only write client if there is something to change
      if (fakeDelta != 0 || dispoDelta != 0) {
        final clientUpdates = <String, dynamic>{};
        if (fakeDelta != 0) {
          clientUpdates['plafondFake'] = FieldValue.increment(fakeDelta);
        }
        if (dispoDelta != 0) {
          clientUpdates['plafondDisponible'] = FieldValue.increment(dispoDelta);
        }
        tx.update(clientRef, clientUpdates);
      }
    });
  }

  // ─── Desired Quantity (orderBeton) ──────────────────────────────────────────

  Stream<List<OrderBetonModel>> watchOrderBetons() {
    return _db
        .collection(AppConstants.orderBetonCollection)
        .orderBy('createDate', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => OrderBetonModel.fromMap(d.data(), d.id)).toList());
  }

  // ─── Order History ──────────────────────────────────────────────────────────

  Stream<List<OrderHistoryModel>> watchOrderHistory(String orderId) {
    return _db
        .collection(AppConstants.ordersCollection)
        .doc(orderId)
        .collection(AppConstants.orderHistoryCollection)
        .orderBy('modifiedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => OrderHistoryModel.fromMap(d.data(), d.id)).toList());
  }

  Stream<List<OrderHistoryModel>> watchAllHistory() {
    return _db
        .collectionGroup(AppConstants.orderHistoryCollection)
        .orderBy('modifiedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => OrderHistoryModel.fromMap(d.data(), d.id)).toList());
  }

  // ─── Commercials / Operators ─────────────────────────────────────────────────

  Stream<List<CommercialModel>> watchStaff() {
    return _db
        .collection(AppConstants.commercialsCollection)
        .snapshots()
        .map((s) => s.docs.map((d) => CommercialModel.fromMap(d.data(), d.id)).toList());
  }

  Future<CommercialModel?> getCommercial(String id) async {
    final doc = await _db.collection(AppConstants.commercialsCollection).doc(id).get();
    if (!doc.exists) return null;
    return CommercialModel.fromMap(doc.data()!, doc.id);
  }

  Future<void> updateStaff(String id, Map<String, dynamic> data) async {
    await _db.collection(AppConstants.commercialsCollection).doc(id).update(data);
  }

  Future<void> updateUserRole(String uid, String role) async {
    await _db.collection(AppConstants.usersCollection).doc(uid).update({'role': role});
  }

  /// Safe delete: removes Firestore docs. Firebase Auth account must be deleted
  /// via Firebase console or Cloud Functions (client SDK cannot delete other users).
  Future<void> deleteStaff(String id) async {
    final batch = _db.batch();
    batch.delete(_db.collection(AppConstants.commercialsCollection).doc(id));
    batch.delete(_db.collection(AppConstants.usersCollection).doc(id));
    await batch.commit();
  }
}
