import 'package:talkhimik_app/domain/models/log_entry.dart';
import 'package:talkhimik_app/domain/repositories/log_store.dart';

/// Test/demo [LogStore] with no persistence. Widget tests override the
/// provider with this so nothing touches disk.
class InMemoryLogStore implements LogStore {
  final List<GestureLogEntry> events = [];
  final List<SessionMeta> sessionList = [];
  final List<SyncQueueEntry> syncQueue = [];
  int _nextId = 1;

  @override
  Future<void> init() async {}

  @override
  Future<GestureLogEntry> appendEvent(GestureLogEntry entry) async {
    final stored = entry.withId(_nextId++);
    events.add(stored);
    syncQueue.add(
      SyncQueueEntry(id: syncQueue.length, logEntryId: stored.id!, createdAt: DateTime.now()),
    );
    return stored;
  }

  @override
  Future<List<GestureLogEntry>> eventsForSession(String sessionId) async =>
      events.where((e) => e.sessionId == sessionId).toList();

  @override
  Future<void> startSession(SessionMeta session) async {
    sessionList.removeWhere((s) => s.sessionId == session.sessionId);
    sessionList.add(session);
  }

  @override
  Future<List<SessionMeta>> sessions() async =>
      [...sessionList]..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  @override
  Future<List<SyncQueueEntry>> pendingSyncs() async => List.of(syncQueue);

  @override
  Future<void> markSynced(List<int> ids) async {
    syncQueue.removeWhere((e) => ids.contains(e.id));
  }

  @override
  Future<void> close() async {}
}
