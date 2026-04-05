import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/services/auth_service.dart';
import '../data/repositories/firestore_repository.dart';
import '../data/models/models.dart';

// ─── Services ─────────────────────────────────────────────────────────────────

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final firestoreRepoProvider = Provider<FirestoreRepository>((ref) => FirestoreRepository());

// ─── Auth State ───────────────────────────────────────────────────────────────

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserRoleProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return ref.read(authServiceProvider).getCurrentUserRole();
});

final currentCommercialProvider = FutureProvider<CommercialModel?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return ref.read(firestoreRepoProvider).getCommercial(user.uid);
});

// ─── Orders ───────────────────────────────────────────────────────────────────

final activeOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  return ref.watch(firestoreRepoProvider).watchActiveOrders();
});

final finishedOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  return ref.watch(firestoreRepoProvider).watchFinishedOrders();
});

final commercialOrdersProvider = StreamProvider.family<List<OrderModel>, String>((ref, commercialId) {
  return ref.watch(firestoreRepoProvider).watchOrdersForCommercial(commercialId);
});

// ─── History ──────────────────────────────────────────────────────────────────

final allHistoryProvider = StreamProvider<List<OrderHistoryModel>>((ref) {
  return ref.watch(firestoreRepoProvider).watchAllHistory();
});

final orderHistoryProvider = StreamProvider.family<List<OrderHistoryModel>, String>((ref, orderId) {
  return ref.watch(firestoreRepoProvider).watchOrderHistory(orderId);
});

// ─── Staff ────────────────────────────────────────────────────────────────────

final staffProvider = StreamProvider<List<CommercialModel>>((ref) {
  return ref.watch(firestoreRepoProvider).watchStaff();
});

// ─── Clients ──────────────────────────────────────────────────────────────────

final clientsProvider = StreamProvider<List<ClientModel>>((ref) {
  return ref.watch(firestoreRepoProvider).watchClients();
});

// ─── Betons ───────────────────────────────────────────────────────────────────

final betonsProvider = StreamProvider<List<BetonModel>>((ref) {
  return ref.watch(firestoreRepoProvider).watchBetons();
});

// ─── BetonChantier per client ─────────────────────────────────────────────────

final betonChantiersProvider = StreamProvider.family<List<BetonChantierModel>, String>((ref, clientId) {
  return ref.watch(firestoreRepoProvider).watchBetonChantiers(clientId);
});

// Reactive betons available for a specific client x chantier pair (used by order form)
final betonChantiersByChantierProvider = StreamProvider.family<
    List<BetonChantierModel>, ({String clientId, String chantier})>((ref, args) {
  return ref
      .watch(firestoreRepoProvider)
      .watchBetonChantiersByChantier(args.clientId, args.chantier);
});

// ─── Order Betons (desired quantity) ──────────────────────────────────────────

final orderBetonsProvider = StreamProvider<List<OrderBetonModel>>((ref) {
  return ref.watch(firestoreRepoProvider).watchOrderBetons();
});

// ─── Order Filter State ───────────────────────────────────────────────────────

class OrderFilter {
  final String? clientName;
  final String? chantier;
  final String? commercialName;
  final String? betonType;
  final DateTime? startDate;
  final DateTime? endDate;

  const OrderFilter({
    this.clientName,
    this.chantier,
    this.commercialName,
    this.betonType,
    this.startDate,
    this.endDate,
  });

  OrderFilter copyWith({
    String? clientName,
    String? chantier,
    String? commercialName,
    String? betonType,
    DateTime? startDate,
    DateTime? endDate,
    // clear flags explicitly null a field
    bool clearClient = false,
    bool clearChantier = false,
    bool clearCommercial = false,
    bool clearBeton = false,
    bool clearStartDate = false,
    bool clearEndDate = false,
  }) {
    return OrderFilter(
      clientName:     clearClient     ? null : (clientName     ?? this.clientName),
      chantier:       clearChantier   ? null : (chantier       ?? this.chantier),
      commercialName: clearCommercial ? null : (commercialName ?? this.commercialName),
      betonType:      clearBeton      ? null : (betonType      ?? this.betonType),
      startDate:      clearStartDate  ? null : (startDate      ?? this.startDate),
      endDate:        clearEndDate    ? null : (endDate        ?? this.endDate),
    );
  }

  bool get isEmpty =>
      clientName == null &&
          chantier == null &&
          commercialName == null &&
          betonType == null &&
          startDate == null &&
          endDate == null;
}

class OrderFilterNotifier extends StateNotifier<OrderFilter> {
  OrderFilterNotifier() : super(const OrderFilter());

  void update(OrderFilter filter) => state = filter;
  void reset() => state = const OrderFilter();
}

final orderFilterProvider = StateNotifierProvider<OrderFilterNotifier, OrderFilter>(
      (ref) => OrderFilterNotifier(),
);
// ─── Dashboard view mode (cards vs table) ────────────────────────────────────

enum DashboardViewMode { cards, table }

final dashboardViewModeProvider = StateProvider<DashboardViewMode>(
      (ref) => DashboardViewMode.cards,
);
