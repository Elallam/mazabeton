import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─── User Model ───────────────────────────────────────────────────────────────
class UserModel {
  final String id;
  final String role;

  const UserModel({required this.id, required this.role});

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(id: id, role: map['role'] ?? '');
  }

  Map<String, dynamic> toMap() => {'role': role};
}

// ─── Commercial Model ─────────────────────────────────────────────────────────
class CommercialModel {
  final String id;
  final String firstname;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String role; // 'commercial' or 'operator'
  final String password;

  const CommercialModel({
    required this.id,
    required this.firstname,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.role,
    required this.password
  });

  factory CommercialModel.fromMap(Map<String, dynamic> map, String id) {
    return CommercialModel(
      id: id,
      firstname: map['firstname'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      role: map['role'] ?? 'commercial',
      password: map['password'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'firstname': firstname,
    'name': name,
    'email': email,
    'phone': phone,
    'address': address,
    'role': role,
    'password' : password
  };

  CommercialModel copyWith({
    String? id,
    String? firstname,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? role,
    String? password,
  }){
    return CommercialModel(id: id ?? this.id, firstname: firstname ?? this.firstname,
        name: name ?? this.name, email: email ?? this.email, phone: phone ?? this.phone,
        address: address ?? this.address, role: role ?? this.role, password: password ?? this.password);
}

  String get fullName => '$firstname $name';
}

// ─── Client Model ─────────────────────────────────────────────────────────────
class ClientModel {
  final String id;
  final String name;
  final String firstName;
  final String phone;
  final String company;
  final String address;
  final String managerName;
  final String contactName;
  final String contactPhone;
  final double plafond;
  final double plafondDisponible;
  final double plafondFake;
  final bool isBlocked;
  final bool isDeleted;
  final List<String> chantiers;

  const ClientModel({
    required this.id,
    required this.name,
    required this.firstName,
    required this.phone,
    required this.company,
    required this.address,
    required this.managerName,
    required this.contactName,
    required this.contactPhone,
    required this.plafond,
    required this.plafondDisponible,
    required this.plafondFake,
    required this.isBlocked,
    required this.isDeleted,
    required this.chantiers,
  });

  factory ClientModel.fromMap(Map<String, dynamic> map, String id) {
    return ClientModel(
      id: id,
      name: map['name'] ?? '',
      firstName: map['firstName'] ?? '',
      phone: map['phone'] ?? '',
      company: map['company'] ?? '',
      address: map['address'] ?? '',
      managerName: map['managerName'] ?? '',
      contactName: map['contactName'] ?? '',
      contactPhone: map['contactPhone'] ?? '',
      plafond: (map['plafond'] ?? 0).toDouble(),
      plafondDisponible: (map['plafondDisponible'] ?? 0).toDouble(),
      plafondFake: (map['plafondFake'] ?? 0).toDouble(),
      isBlocked: map['isBlocked'] ?? false,
      isDeleted: map['delete'] ?? false,
      chantiers: List<String>.from(map['chantiers'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'firstName': firstName,
    'phone': phone,
    'company': company,
    'address': address,
    'managerName': managerName,
    'contactName': contactName,
    'contactPhone': contactPhone,
    'plafond': plafond,
    'plafondDisponible': plafondDisponible,
    'plafondFake': plafondFake,
    'isBlocked': isBlocked,
    'delete': isDeleted,
    'chantiers': chantiers,
  };

  String get fullName => '$firstName $name';
  bool get hasReachedPlafond => plafondDisponible <= 0;
}

// ─── Beton Model ──────────────────────────────────────────────────────────────
class BetonModel {
  final String id;
  final String name;
  final String category;

  const BetonModel({
    required this.id,
    required this.name,
    required this.category,
  });

  factory BetonModel.fromMap(Map<String, dynamic> map, String id) {
    return BetonModel(
      id: id,
      name: map['name'] ?? '',
      category: map['category'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'category': category,
  };
}

// ─── BetonChantier Model ──────────────────────────────────────────────────────
class BetonChantierModel {
  final String id;
  final String betonId;
  final String chantier;
  final String clientId;
  final double prix;

  const BetonChantierModel({
    required this.id,
    required this.betonId,
    required this.chantier,
    required this.clientId,
    required this.prix,
  });

  factory BetonChantierModel.fromMap(Map<String, dynamic> map, String id) {
    return BetonChantierModel(
      id: id,
      betonId: map['betonId'] ?? '',
      chantier: map['chantier'] ?? '',
      clientId: map['clientId'] ?? '',
      prix: (map['prix'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'betonId': betonId,
    'chantier': chantier,
    'clientId': clientId,
    'prix': prix,
  };
}

// ─── Order Model ──────────────────────────────────────────────────────────────
class OrderModel {
  final String id;
  final String orderId;
  final String beton;
  final String betonId;
  final double betonPrice;
  final String chantier;
  final String clientId;
  final String commercialId;
  final String contact;
  final String contactPhone;
  final DateTime createdAt;
  final DateTime? deliveryDate;
  final double qteDemande;
  final double qteLivre;
  final bool soldPaid;
  final String status;
  final double supplement;

  const OrderModel({
    required this.id,
    required this.orderId,
    required this.beton,
    required this.betonId,
    required this.betonPrice,
    required this.chantier,
    required this.clientId,
    required this.commercialId,
    required this.contact,
    required this.contactPhone,
    required this.createdAt,
    this.deliveryDate,
    required this.qteDemande,
    required this.qteLivre,
    required this.soldPaid,
    required this.status,
    required this.supplement,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map, String id) {
    return OrderModel(
      id: id,
      orderId: map['OrderId'] ?? '',
      beton: map['beton'] ?? '',
      betonId: map['betonId'] ?? '',
      betonPrice: (map['betonPrice'] ?? 0).toDouble(),
      chantier: map['chantier'] ?? '',
      clientId: map['clientId'] ?? '',
      commercialId: map['commercialId'] ?? '',
      contact: map['contact'] ?? '',
      contactPhone: map['contactPhone'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deliveryDate: (map['deliveryDate'] as Timestamp?)?.toDate(),
      qteDemande: (map['qteDemande'] ?? 0).toDouble(),
      qteLivre: (map['qteLivre'] ?? 0).toDouble(),
      soldPaid: map['soldPaid'] ?? false,
      status: map['status'] ?? 'pending',
      supplement: (map['supplement'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'OrderId': orderId,
    'beton': beton,
    'betonId': betonId,
    'betonPrice': betonPrice,
    'chantier': chantier,
    'clientId': clientId,
    'commercialId': commercialId,
    'contact': contact,
    'contactPhone': contactPhone,
    'createdAt': Timestamp.fromDate(createdAt),
    'deliveryDate': deliveryDate != null ? Timestamp.fromDate(deliveryDate!) : null,
    'qteDemande': qteDemande,
    'qteLivre': qteLivre,
    'soldPaid': soldPaid,
    'status': status,
    'supplement': supplement,
  };

  bool get isActive => status == 'pending' || status == 'in_progress';
  bool get isFinished => status == 'delivered' || status == 'canceled';
  double get totalQuantity => qteDemande + supplement;
}

// ─── OrderBeton Model ─────────────────────────────────────────────────────────
class OrderBetonModel {
  final String id;
  final DateTime createDate;
  final double qte;

  const OrderBetonModel({
    required this.id,
    required this.createDate,
    required this.qte,
  });

  factory OrderBetonModel.fromMap(Map<String, dynamic> map, String id) {
    return OrderBetonModel(
      id: id,
      createDate: (map['createDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      qte: (map['qte'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'createDate': Timestamp.fromDate(createDate),
    'qte': qte,
  };
}

// ─── OrderHistory Model ───────────────────────────────────────────────────────
class OrderHistoryModel {
  final String id;
  final Map<String, dynamic> oldData;
  final Map<String, dynamic> newData;
  final String commercialId;
  final String commercialName;
  final DateTime modifiedAt;

  const OrderHistoryModel({
    required this.id,
    required this.oldData,
    required this.newData,
    required this.commercialId,
    required this.commercialName,
    required this.modifiedAt,
  });

  factory OrderHistoryModel.fromMap(Map<String, dynamic> map, String id) {
    return OrderHistoryModel(
      id: id,
      oldData: Map<String, dynamic>.from(map['oldData'] ?? {}),
      newData: Map<String, dynamic>.from(map['newData'] ?? {}),
      commercialId: map['commercialId'] ?? '',
      commercialName: map['commercialName'] ?? '',
      modifiedAt: (map['modifiedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'oldData': oldData,
    'newData': newData,
    'commercialId': commercialId,
    'commercialName': commercialName,
    'modifiedAt': Timestamp.fromDate(modifiedAt),
  };
}

class MockUserCredential implements UserCredential {
  @override
  final FirebaseAuth auth;
  @override
  final AuthCredential? credential;
  @override
  final AdditionalUserInfo? additionalUserInfo;
  @override
  final User user;

  MockUserCredential({
    required this.auth,
    this.credential,
    this.additionalUserInfo,
    required this.user,
  });
}

