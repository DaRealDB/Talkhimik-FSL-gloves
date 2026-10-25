import 'package:hive_ce/hive.dart';

import '../../domain/models/log_entry.dart';
import '../../domain/repositories/log_store.dart';
import 'hive_adapters.dart';

/// Hive-backed [LogStore]. Pure Dart — identical behavior on the Windows
/// dev machine and Android field devices.
class HiveLogStore implements LogStore {
  HiveLogStore(this._hive, {String boxPrefix = ''})
      : _eventsBox = '${boxPrefix}events',
        _syncBox = '${boxPrefix}syncQueue',
        _sessionsBox = '${boxPrefix}sessions';

  final HiveInterface _hive;
  final String _eventsBox;
  final String _syncBox;
  final String _sessionsBox;

  late Box<GestureLogEntry> _events;
  late Box<SyncQueueEntry> _syncQueue;
  late Box<SessionMeta> _sessions;

  static bool _adaptersRegistered = false;

  /// Registers the hand-written adapters exactly once per isolate.
  static void registerAdapters(HiveInterface hive) {
    if (_adaptersRegistered) return;
    hive
      ..registerAdapter(GestureLogEntryAdapter(), internal: true)
      ..registerAdapter(SyncQueueEntryAdapter(), internal: true)
      ..registerAdapter(SessionMetaAdapter(), internal: true);
    _adaptersRegistered = true;
  }

  @override
  Future<void> init() async {
    registerAdapters(_hive);
    _events = await _hive.openBox<GestureLogEntry>(_eventsBox);
    _syncQueue = await _hive.openBox<SyncQueueEntry>(_syncBox);
    _sessions = await _hive.openBox<SessionMeta>(_sessionsBox);
  }

  @override
  Future<GestureLogEntry> appendEvent(GestureLogEntry entry) async {
    final key = await _events.add(entry);
    final stored = entry.withId(key);
    await _events.put(key, stored);
    // FR-10 / C-S4: every event enters the offline sync queue.
    await _syncQueue.add(
      SyncQueueEntry(id: 0, logEntryId: key, createdAt: DateTime.now()),
    );
    return stored;
  }

  @override
  Future<List<GestureLogEntry>> eventsForSession(String sessionId) async =>
      _events.values
          .where((e) => e.sessionId == sessionId)
          .toList()
        ..sort((a, b) => a.receivedAt.compareTo(b.receivedAt));

  @override
  Future<void> startSession(SessionMeta session) =>
      _sessions.put(session.sessionId, session);

  @override
  Future<List<SessionMeta>> sessions() async =>
      _sessions.values.toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  @override
  Future<List<SyncQueueEntry>> pendingSyncs() async => [
        for (final e in _syncQueue.toMap().entries)
          SyncQueueEntry(
            id: e.key,
            logEntryId: e.value.logEntryId,
            createdAt: e.value.createdAt,
          ),
      ];

  @override
  Future<void> markSynced(List<int> ids) async {
    for (final id in ids) {
      await _syncQueue.delete(id);
    }
  }

  @override
  Future<void> close() async {
    await _events.close();
    await _syncQueue.close();
    await _sessions.close();
  }
}
