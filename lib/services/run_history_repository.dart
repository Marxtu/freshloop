import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models/run_record.dart';

/// Stores completed runs. M5.1 persists locally; M5.2 swaps in Firebase.
abstract class RunHistoryRepository {
  Future<void> save(RunRecord record);
  Future<List<RunRecord>> all(); // newest first
}

class SharedPrefsRunHistoryRepository implements RunHistoryRepository {
  static const _key = 'run_history_v1';
  final SharedPreferences _prefs;
  SharedPrefsRunHistoryRepository(this._prefs);

  @override
  Future<List<RunRecord>> all() async {
    final raw = _prefs.getStringList(_key) ?? const [];
    return raw
        .map((s) => RunRecord.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList()
        .reversed
        .toList();
  }

  @override
  Future<void> save(RunRecord record) async {
    final raw = _prefs.getStringList(_key) ?? <String>[];
    raw.add(jsonEncode(record.toJson()));
    await _prefs.setStringList(_key, raw);
  }
}
