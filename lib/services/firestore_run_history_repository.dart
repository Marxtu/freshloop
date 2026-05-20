import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/run_record.dart';
import 'run_history_repository.dart';

/// Cloud-backed run history under /users/{uid}/runs (matches the security rules).
class FirestoreRunHistoryRepository implements RunHistoryRepository {
  final FirebaseFirestore _db;
  final String uid;
  FirestoreRunHistoryRepository(this._db, this.uid);

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('runs');

  @override
  Future<void> save(RunRecord record) async {
    await _col.add({...record.toJson(), 'createdAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<List<RunRecord>> all() async {
    final snap = await _col.orderBy('createdAt', descending: true).get();
    final out = <RunRecord>[];
    for (final d in snap.docs) {
      try {
        out.add(RunRecord.fromJson(d.data()));
      } catch (_) {/* skip a malformed doc */}
    }
    return out;
  }
}
