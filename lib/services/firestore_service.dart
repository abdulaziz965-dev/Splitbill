import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class FirestoreService {
  static final FirestoreService _i = FirestoreService._();
  factory FirestoreService() => _i;
  FirestoreService._();

  final _db = FirebaseFirestore.instance;

  // Collections
  CollectionReference get _groups => _db.collection('groups');
  CollectionReference _expenses(String gid) =>
      _db.collection('groups').doc(gid).collection('expenses');
  CollectionReference _bills(String gid) =>
      _db.collection('groups').doc(gid).collection('bills');

  // ── Groups ────────────────────────────────────────────────────────────────

  /// Generate a unique 4-digit join code
  Future<String> _generateUniqueCode() async {
    final rng = Random();
    while (true) {
      final code = (1000 + rng.nextInt(9000)).toString();
      final snap = await _groups.where('joinCode', isEqualTo: code).limit(1).get();
      if (snap.docs.isEmpty) return code;
    }
  }

  /// Create a new group
  Future<GroupChat> createGroup({
    required String name,
    required String createdBy,
    String? upiId,
    String? upiName,
  }) async {
    final code = await _generateUniqueCode();
    final group = GroupChat(
      name: name,
      joinCode: code,
      createdBy: createdBy,
      members: [createdBy],
      upiId: upiId,
      upiName: upiName,
    );
    await _groups.doc(group.id).set(group.toFirestore());
    return group;
  }

  /// Join a group via 4-digit code
  Future<GroupChat?> joinGroup({
    required String code,
    required String username,
  }) async {
    final snap = await _groups.where('joinCode', isEqualTo: code).limit(1).get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    final group = GroupChat.fromFirestore(doc);
    if (!group.members.contains(username)) {
      await doc.reference.update({
        'members': FieldValue.arrayUnion([username]),
      });
    }
    // Refetch to get updated doc
    final updated = await doc.reference.get();
    return GroupChat.fromFirestore(updated);
  }

  /// Stream all groups the user is a member of
  Stream<List<GroupChat>> streamUserGroups(String username) {
    return _groups
        .where('members', arrayContains: username)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(GroupChat.fromFirestore).toList());
  }

  /// Get single group
  Future<GroupChat?> getGroup(String groupId) async {
    final doc = await _groups.doc(groupId).get();
    if (!doc.exists) return null;
    return GroupChat.fromFirestore(doc);
  }

  /// Update group UPI details
  Future<void> updateGroupUpi(String groupId, String upiId, String upiName) =>
      _groups.doc(groupId).update({'upiId': upiId, 'upiName': upiName});

  // ── Expenses ──────────────────────────────────────────────────────────────

  /// Add expense to group
  Future<void> addExpense(String groupId, Expense expense) =>
      _expenses(groupId).doc(expense.id).set(expense.toFirestore());

  /// Delete expense
  Future<void> deleteExpense(String groupId, String expenseId) =>
      _expenses(groupId).doc(expenseId).delete();

  /// Stream expenses for a group
  Stream<List<Expense>> streamExpenses(String groupId) {
    return _expenses(groupId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => Expense.fromFirestore(d.data() as Map<String, dynamic>))
            .toList());
  }

  // ── Bills ─────────────────────────────────────────────────────────────────

  /// Create bill in group
  Future<void> createBill(Bill bill) =>
      _bills(bill.groupId).doc(bill.id).set(bill.toFirestore());

  /// Stream bills for a group
  Stream<List<Bill>> streamBills(String groupId) {
    return _bills(groupId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Bill.fromFirestore).toList());
  }

  /// Get single bill
  Future<Bill?> getBill(String groupId, String billId) async {
    final doc = await _bills(groupId).doc(billId).get();
    if (!doc.exists) return null;
    return Bill.fromFirestore(doc);
  }

  /// Mark participant as paid (and persist to Firestore)
  Future<void> markParticipantPaid({
    required String groupId,
    required String billId,
    required String participantId,
    required bool paid,
  }) async {
    final doc = await _bills(groupId).doc(billId).get();
    if (!doc.exists) return;
    final bill = Bill.fromFirestore(doc);
    final participants = bill.participants.map((p) {
      if (p.id == participantId) {
        return Participant(
          id: p.id,
          name: p.name,
          share: p.share,
          hasPaid: paid,
          paidAt: paid ? DateTime.now() : null,
        );
      }
      return p;
    }).toList();
    await _bills(groupId).doc(billId).update({
      'participants': participants.map((p) => p.toFirestore()).toList(),
    });
  }

  /// Stream a live bill
  Stream<Bill?> streamBill(String groupId, String billId) {
    return _bills(groupId).doc(billId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Bill.fromFirestore(doc);
    });
  }

  /// Update blockchain record on a bill
  Future<void> updateBillBlockchain(String groupId, String billId, AlgorandRecord record) =>
      _bills(groupId).doc(billId).update({
        'txId': record.txId,
        'confirmedRound': record.confirmedRound,
      });
}
