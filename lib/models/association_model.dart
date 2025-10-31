import 'package:cloud_firestore/cloud_firestore.dart';

class AssociationModel {
  final String id;
  final String name;
  final String description;
  final String adminId;
  final List<String> memberIds;
  final List<String> coAdmins;
  final double monthlyContribution;
  final int numberOfMembers;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime payoutDate;
  final Map<String, int> payoutMonths;
  final Map<String, Map<String, dynamic>> payments;
  final bool isDrawComplete;
  final DateTime createdAt;
  final String status;
  final String? bankAccountNumber;
  final String? cliqName;
  final String? cliqNumber;
  final bool isAdmin;

  const AssociationModel({
    required this.id,
    required this.name,
    required this.description,
    required this.adminId,
    required this.memberIds,
    this.coAdmins = const [],
    required this.monthlyContribution,
    required this.numberOfMembers,
    required this.startDate,
    required this.endDate,
    required this.payoutDate,
    required this.payoutMonths,
    required this.payments,
    required this.isDrawComplete,
    required this.createdAt,
    required this.status,
    this.bankAccountNumber,
    this.cliqName,
    this.cliqNumber,
    this.isAdmin = false,
  });

  double get totalAmountPerUser => monthlyContribution * (numberOfMembers - 1);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'adminId': adminId,
      'memberIds': memberIds,
      'coAdmins': coAdmins,
      'monthlyContribution': monthlyContribution,
      'numberOfMembers': numberOfMembers,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'payoutDate': Timestamp.fromDate(payoutDate),
      'payoutMonths': payoutMonths,
      'payments': payments,
      'isDrawComplete': isDrawComplete,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'bankAccountNumber': bankAccountNumber,
      'cliqName': cliqName,
      'cliqNumber': cliqNumber,
      'isAdmin': isAdmin,
    };
  }

  factory AssociationModel.fromMap(Map<String, dynamic> map) {
    return AssociationModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      adminId: map['adminId'] ?? '',
      memberIds: List<String>.from(map['memberIds'] ?? []),
      coAdmins: List<String>.from(map['coAdmins'] ?? []),
      monthlyContribution: map['monthlyContribution']?.toDouble() ?? 0.0,
      numberOfMembers: map['numberOfMembers']?.toInt() ?? 0,
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      payoutDate: (map['payoutDate'] as Timestamp).toDate(),
      payoutMonths: Map<String, int>.from(map['payoutMonths'] ?? {}),
      payments: Map<String, Map<String, dynamic>>.from(map['payments'] ?? {}),
      isDrawComplete: map['isDrawComplete'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      status: map['status'] ?? 'active',
      bankAccountNumber: map['bankAccountNumber'],
      cliqName: map['cliqName'],
      cliqNumber: map['cliqNumber'],
      isAdmin: map['isAdmin'] ?? false,
    );
  }

  AssociationModel copyWith({
    String? id,
    String? name,
    String? description,
    String? adminId,
    List<String>? memberIds,
    List<String>? coAdmins,
    double? monthlyContribution,
    int? numberOfMembers,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? payoutDate,
    Map<String, int>? payoutMonths,
    Map<String, Map<String, dynamic>>? payments,
    bool? isDrawComplete,
    DateTime? createdAt,
    String? status,
    String? bankAccountNumber,
    String? cliqName,
    String? cliqNumber,
    bool? isAdmin,
  }) {
    return AssociationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      adminId: adminId ?? this.adminId,
      memberIds: memberIds ?? this.memberIds,
      coAdmins: coAdmins ?? this.coAdmins,
      monthlyContribution: monthlyContribution ?? this.monthlyContribution,
      numberOfMembers: numberOfMembers ?? this.numberOfMembers,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      payoutDate: payoutDate ?? this.payoutDate,
      payoutMonths: payoutMonths ?? this.payoutMonths,
      payments: payments ?? this.payments,
      isDrawComplete: isDrawComplete ?? this.isDrawComplete,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      cliqName: cliqName ?? this.cliqName,
      cliqNumber: cliqNumber ?? this.cliqNumber,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }

  @override
  String toString() {
    return 'AssociationModel(id: $id, name: $name, adminId: $adminId, monthlyContribution: $monthlyContribution, numberOfMembers: $numberOfMembers)';
  }
}
