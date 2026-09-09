import '../models/log_entry.dart';
import '../models/participant.dart';

/// Local persistence for recognition events, sessions, the offline sync
/// queue, and participant profiles (SRS FR-10, FR-13, FR-16).
///
/// The Hive implementation backs this on both Windows (dev) and Android
/// (field). A Firestore-backed implementation can replace it later without
/// touching the application layer.
abstract interface class LogStore {
  Future<void> init();

  /// Appends one recognition event and queues it for cloud sync.
  /// Returns the stored entry with its assigned id.
  Future<GestureLogEntry> appendEvent(GestureLogEntry entry);

  Future<List<GestureLogEntry>> eventsForSession(String sessionId);

  Future<void> startSession(SessionMeta session);

  /// All sessions, newest first.
  Future<List<SessionMeta>> sessions();

  Future<void> upsertParticipant(ParticipantProfile profile);

  Future<ParticipantProfile?> getParticipant(String id);

  Future<List<ParticipantProfile>> allParticipants();

  /// Entries still waiting for cloud flush (offline queue, C-S4).
  Future<List<SyncQueueEntry>> pendingSyncs();

  /// Marks queue entries as synced after a successful flush.
  Future<void> markSynced(List<int> ids);

  Future<void> close();
}
