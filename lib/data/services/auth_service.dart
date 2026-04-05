import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/models.dart';
import '../../core/constants/app_constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in and return the user's role
  Future<String?> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    final uid = cred.user!.uid;
    final doc = await _firestore.collection(AppConstants.usersCollection).doc(uid).get();
    if (!doc.exists) return null;
    return doc.data()!['role'] as String?;
  }

  /// Create a commercial or operator account (admin only)
  Future<void> createStaffAccount({
    required String email,
    required String password,
    required String role,
    required String firstname,
    required String name,
    required String phone,
    required String address,
  }) async {
    // Create Firebase Auth user using secondary app instance to avoid signing out admin
    FirebaseApp defaultApp = Firebase.app();
    final secondary = await await Firebase.initializeApp(
      name: 'Secondary',
      options: defaultApp.options,
    );

    final secondaryAuth = FirebaseAuth.instanceFor(app: secondary);
    // We use the REST API approach: create via admin SDK would be ideal, but for
    // client-only we temporarily sign in and then restore admin session.
    // Instead, use Cloud Functions in production. Here we use email link for simplicity.

    // NOTE: In production, this should use Firebase Admin SDK via Cloud Functions.
    // For this MVP, we create the user and immediately sign the admin back in.
    final adminEmail = _auth.currentUser?.email;
    // This is a placeholder — real implementation uses Cloud Functions
    final userCred = await secondaryAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    secondaryAuth.signOut();
    final uid = userCred.user!.uid;

    // Write to users collection
    await _firestore.collection(AppConstants.usersCollection).doc(uid).set({
      'id' : uid,
      'role': role,
    });

    // Write to commercials collection
    await _firestore.collection(AppConstants.commercialsCollection).doc(uid).set({
      'id': uid,
      'firstname': firstname,
      'name': name,
      'email': email.trim(),
      'phone': phone,
      'address': address,
      'role': role,
      'password': password
    });
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<String?> getCurrentUserRole() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _firestore.collection(AppConstants.usersCollection).doc(uid).get();
    return doc.data()?['role'] as String?;
  }

  /// Update a staff member's password using Firebase Auth REST API
  /// (stores password in Firestore for admin visibility, updates Auth via REST)
  Future<void> updateStaffPassword(CommercialModel commercial, String newPassword) async {
    // Store visible password in Firestore (as requested for admin visibility)
    await _firestore.collection(AppConstants.commercialsCollection).doc(commercial.id).update({
      'password': newPassword,
    });
    // In production use Firebase Admin SDK / Cloud Functions to update Auth password.
    // Client-side cannot update another user's Auth password directly.
    FirebaseApp defaultApp = Firebase.app();
    final secondary = await await Firebase.initializeApp(
      name: 'Secondary',
      options: defaultApp.options,
    );

    final secondaryAuth = FirebaseAuth.instanceFor(app: secondary);
    secondaryAuth.signInWithEmailAndPassword(email: commercial.email, password: commercial.password);
    secondaryAuth.currentUser?.updatePassword(newPassword);
    secondaryAuth.signOut();
  }
}
