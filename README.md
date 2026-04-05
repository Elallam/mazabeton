# 🏗️ Mazabeton — Flutter Concrete Management App

A full-stack Flutter + Firebase mobile application for managing concrete orders across three user tiers: **Admin**, **Commercial**, and **Operator**.

---

## 📁 Project Structure

```
lib/
├── core/
│   ├── theme/app_theme.dart          # Dark industrial theme + colors
│   ├── constants/app_constants.dart  # Firebase collections, roles, statuses
│   ├── providers.dart                # All Riverpod providers
│   └── router.dart                   # Role-based GoRouter
├── data/
│   ├── models/models.dart            # All 8 Firestore entities
│   ├── services/auth_service.dart    # Firebase Auth wrapper
│   └── repositories/firestore_repository.dart  # All Firestore CRUD
├── presentation/
│   ├── auth/login_screen.dart        # Animated login screen
│   ├── admin/
│   │   ├── admin_shell.dart          # Bottom nav shell
│   │   ├── orders_screen.dart        # Orders + filters + 2 tabs
│   │   ├── staff_screen.dart         # Create/manage team
│   │   ├── history_screen.dart       # Modification logs + PDF download
│   │   └── desired_quantity_screen.dart  # Stats + chart
│   ├── commercial/
│   │   ├── commercial_shell.dart
│   │   ├── commercial_dashboard.dart  # Orders + update quantity/status
│   │   ├── create_order_screen.dart   # Full order form + plafond check
│   │   └── commercial_desired_quantity.dart
│   ├── operator/
│   │   ├── operator_shell.dart
│   │   ├── operator_dashboard.dart    # Read-only orders view
│   │   └── operator_desired_quantity.dart
│   └── shared/
│       ├── widgets/shared_widgets.dart  # OrderCard, StatCard, StatusBadge…
│       └── dialogs/order_detail_dialog.dart
├── firebase_options.dart             # ← Generate with FlutterFire CLI
└── main.dart
```

---

## 🚀 Setup Instructions

### 1. Prerequisites

- Flutter SDK `>=3.0.0`
- Firebase CLI: `npm install -g firebase-tools`
- FlutterFire CLI: `dart pub global activate flutterfire_cli`

### 2. Create Firebase Project

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Create a new project: **mazabeton**
3. Enable **Authentication → Email/Password**
4. Enable **Firestore Database** (start in production mode)

### 3. Configure FlutterFire

```bash
cd mazabeton
flutterfire configure
```

Select your project and platforms (Android/iOS). This generates `lib/firebase_options.dart`.

### 4. Deploy Firestore Rules & Indexes

```bash
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

### 5. Seed Initial Data

In the Firebase Console → Firestore, create these collections manually or use the seed script:

#### `users` collection
```
Document ID: <admin-uid-from-auth>
  role: "admin"
```

#### `betons` → `drztSHN9jmceYokHfewq` → `types` sub-collection
```
Each document:
  name: "B25"       (or B30, B35, etc.)
  category: "Courant"
```

#### Create admin auth user
In Firebase Console → Authentication → Add User:
- Email: `admin@mazabeton.com`
- Password: `123456789`

Then copy the UID and create the corresponding `users` document with `role: "admin"`.

### 6. Install Dependencies & Run

```bash
flutter pub get
flutter run
```

---

## 🔐 User Roles

| Role       | Email example             | Capabilities |
|------------|---------------------------|--------------|
| Admin      | admin@mazabeton.com       | All orders, staff management, history, download logs |
| Commercial | commercial@mazabeton.com  | Dashboard, create orders, update quantity/status |
| Operator   | operator@mazabeton.com    | Read-only dashboard, quantity view |

---

## 📦 Key Dependencies

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | State management |
| `go_router` | Role-based navigation |
| `firebase_auth` | Authentication |
| `cloud_firestore` | Database |
| `flutter_animate` | Animations |
| `fl_chart` | Quantity charts |
| `pdf` + `printing` | Download history logs |
| `google_fonts` | Rajdhani + Space Grotesk typography |

---

## 🏗️ Firestore Schema

```
users/{uid}
  role: string

commercials/{uid}
  firstname, name, email, phone, address, role

clients/{id}
  name, firstName, phone, plafond, plafondDisponible, plafondFake,
  managerName, contactName, contactPhone, company, chantiers[], address,
  isBlocked, delete

betons/drztSHN9jmceYokHfewq/types/{id}
  name, category

betonChantier/{id}
  betonId, chantier, clientId, prix

orders/{id}
  OrderId, beton, betonId, betonPrice, chantier, clientId, commercialId,
  contact, contactPhone, createdAt, deliveryDate, qteDemande, qteLivre,
  soldPaid, status, supplement
  
  /orderHistory/{id}
    oldData, newData, commercialId, commercialName, modifiedAt

orderBeton/{id}
  createDate, qte
```

---

## 📝 Notes

- **Staff creation**: Creating commercial/operator accounts from the admin panel signs out the admin temporarily (Firebase Auth limitation on client-only apps). For production, use **Firebase Admin SDK via Cloud Functions**.
- **Plafond check**: The `create_order_screen.dart` checks `plafondDisponible <= 0` or `isBlocked` before allowing order creation.
- **History logs**: Every update to an order creates an immutable sub-document in `orderHistory`. Firestore rules prevent updates/deletes on these records.
