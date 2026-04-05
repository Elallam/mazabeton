import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../../core/constants/app_constants.dart';

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

  Future<String> createOrder(OrderModel order) async {
    final ref = _db.collection(AppConstants.ordersCollection).doc();
    final withId = OrderModel(
      id: ref.id,
      orderId: ref.id.substring(0, 8).toUpperCase(),
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
    await ref.set(withId.toMap());
    return ref.id;
  }

  Future<void> updateOrder(
      String orderId,
      Map<String, dynamic> updates,
      OrderModel oldOrder,
      String commercialId,
      String commercialName,
      ) async {
    final batch = _db.batch();

    // Update order
    final orderRef = _db.collection(AppConstants.ordersCollection).doc(orderId);
    batch.update(orderRef, updates);

    // Write history
    final histRef = _db
        .collection(AppConstants.ordersCollection)
        .doc(orderId)
        .collection(AppConstants.orderHistoryCollection)
        .doc();
    batch.set(histRef, {
      'oldData': oldOrder.toMap(),
      'newData': updates,
      'commercialId': commercialId,
      'commercialName': commercialName,
      'modifiedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
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

  Future<void> deleteStaff(String id) async {
    final batch = _db.batch();
    // Todo : update this delete to do a soft delete
    batch.delete(_db.collection(AppConstants.commercialsCollection).doc(id));
    batch.delete(_db.collection(AppConstants.usersCollection).doc(id));
    await batch.commit();
  }
}
