import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

// ─── Group Chat (GC) ────────────────────────────────────────────────────────

class GroupChat {
  final String id;
  final String name;
  final String joinCode;       // 4-digit code
  final String createdBy;      // username
  final List<String> members;  // usernames
  final String? upiId;         // UPI ID for payments e.g. aziz@upi
  final String? upiName;       // display name on QR
  final DateTime createdAt;

  GroupChat({
    String? id,
    required this.name,
    required this.joinCode,
    required this.createdBy,
    List<String>? members,
    this.upiId,
    this.upiName,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        members = members ?? [],
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'name': name,
        'joinCode': joinCode,
        'createdBy': createdBy,
        'members': members,
        'upiId': upiId,
        'upiName': upiName,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory GroupChat.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GroupChat(
      id: d['id'] ?? doc.id,
      name: d['name'] ?? '',
      joinCode: d['joinCode'] ?? '',
      createdBy: d['createdBy'] ?? '',
      members: List<String>.from(d['members'] ?? []),
      upiId: d['upiId'],
      upiName: d['upiName'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  GroupChat copyWith({String? upiId, String? upiName, List<String>? members}) =>
      GroupChat(
        id: id,
        name: name,
        joinCode: joinCode,
        createdBy: createdBy,
        members: members ?? this.members,
        upiId: upiId ?? this.upiId,
        upiName: upiName ?? this.upiName,
        createdAt: createdAt,
      );
}

// ─── Expense ─────────────────────────────────────────────────────────────────

class Expense {
  final String id;
  final String title;
  final double amount;
  final String addedBy;
  final DateTime createdAt;

  Expense({
    String? id,
    required this.title,
    required this.amount,
    this.addedBy = '',
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'title': title,
        'amount': amount,
        'addedBy': addedBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory Expense.fromFirestore(Map<String, dynamic> d) => Expense(
        id: d['id'] ?? _uuid.v4(),
        title: d['title'] ?? '',
        amount: (d['amount'] as num?)?.toDouble() ?? 0,
        addedBy: d['addedBy'] ?? '',
        createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  // Legacy JSON (local use)
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'addedBy': addedBy,
        'createdAt': createdAt.toIso8601String(),
      };
}

// ─── Participant ──────────────────────────────────────────────────────────────

class Participant {
  final String id;
  final String name;
  double share;
  bool hasPaid;
  DateTime? paidAt;

  Participant({
    String? id,
    required this.name,
    this.share = 0.0,
    this.hasPaid = false,
    this.paidAt,
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'name': name,
        'share': share,
        'hasPaid': hasPaid,
        'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      };

  factory Participant.fromFirestore(Map<String, dynamic> d) => Participant(
        id: d['id'] ?? _uuid.v4(),
        name: d['name'] ?? '',
        share: (d['share'] as num?)?.toDouble() ?? 0,
        hasPaid: d['hasPaid'] ?? false,
        paidAt: (d['paidAt'] as Timestamp?)?.toDate(),
      );
}

// ─── Bill ─────────────────────────────────────────────────────────────────────

class Bill {
  final String id;
  final String groupId;
  final List<Expense> expenses;
  final List<Participant> participants;
  final double totalAmount;
  final DateTime createdAt;
  final AlgorandRecord? blockchainRecord;

  Bill({
    String? id,
    required this.groupId,
    required this.expenses,
    required this.participants,
    required this.totalAmount,
    DateTime? createdAt,
    this.blockchainRecord,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  int get paidCount => participants.where((p) => p.hasPaid).length;
  int get totalCount => participants.length;
  bool get isSettled => paidCount == totalCount && totalCount > 0;

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'groupId': groupId,
        'expenses': expenses.map((e) => e.toFirestore()).toList(),
        'participants': participants.map((p) => p.toFirestore()).toList(),
        'totalAmount': totalAmount,
        'createdAt': Timestamp.fromDate(createdAt),
        'txId': blockchainRecord?.txId,
        'confirmedRound': blockchainRecord?.confirmedRound,
      };

  factory Bill.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Bill(
      id: d['id'] ?? doc.id,
      groupId: d['groupId'] ?? '',
      expenses: (d['expenses'] as List<dynamic>? ?? [])
          .map((e) => Expense.fromFirestore(e as Map<String, dynamic>))
          .toList(),
      participants: (d['participants'] as List<dynamic>? ?? [])
          .map((p) => Participant.fromFirestore(p as Map<String, dynamic>))
          .toList(),
      totalAmount: (d['totalAmount'] as num?)?.toDouble() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      blockchainRecord: d['txId'] != null
          ? AlgorandRecord(
              txId: d['txId'],
              confirmedRound: d['confirmedRound'] ?? 0,
            )
          : null,
    );
  }

  Bill copyWith({
    AlgorandRecord? blockchainRecord,
    List<Participant>? participants,
  }) =>
      Bill(
        id: id,
        groupId: groupId,
        expenses: expenses,
        participants: participants ?? this.participants,
        totalAmount: totalAmount,
        createdAt: createdAt,
        blockchainRecord: blockchainRecord ?? this.blockchainRecord,
      );
}

// ─── AlgorandRecord ───────────────────────────────────────────────────────────

class AlgorandRecord {
  final String txId;
  final String network;
  final String status;
  final int confirmedRound;
  final DateTime timestamp;

  AlgorandRecord({
    required this.txId,
    this.network = 'Algorand TestNet',
    this.status = 'Confirmed',
    required this.confirmedRound,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get explorerUrl => 'https://testnet.algoexplorer.io/tx/$txId';
  String get shortTxId =>
      txId.length >= 16
          ? '${txId.substring(0, 8)}...${txId.substring(txId.length - 8)}'
          : txId;
}
