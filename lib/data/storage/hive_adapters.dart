import 'package:hive_ce/hive.dart';

import '../../domain/models/log_entry.dart';
import '../../domain/models/participant.dart';

/// Hand-written TypeAdapters for the Hive boxes.
///
/// Deliberately not generated: serialization code the panel can read.
/// If a field is added or removed, bump that adapter's [TypeAdapter.version]
/// and add a migration note in the commit message (plan risk #8).
class GestureLogEntryAdapter extends TypeAdapter<GestureLogEntry> {
  final int typeId = 1;
  final int version = 1;

  @override
  void write(BinaryWriter writer, GestureLogEntry e) {
    writer
      ..writeInt(e.id ?? 0)
      ..writeString(e.participantId)
      ..writeString(e.sessionId)
      ..writeInt(e.wordId)
      ..writeString(e.filipinoText)
      ..writeString(e.englishText)
      ..writeInt(e.confidence)
      ..writeString(e.confidenceLevel)
      ..writeInt(e.latencyMs)
      ..writeInt(e.gloveTimestampMs)
      ..writeInt(e.receivedAt.millisecondsSinceEpoch)
      ..writeBool(e.corrected)
      ..writeBool(e.originalWordId != null)
      ..writeInt(e.originalWordId ?? 0)
      ..writeString(e.source)
      ..writeString(e.appVersion)
      ..writeString(e.modelVersion);
  }

  @override
  GestureLogEntry read(BinaryReader reader) => GestureLogEntry(
        id: reader.readInt(),
        participantId: reader.readString(),
        sessionId: reader.readString(),
        wordId: reader.readInt(),
        filipinoText: reader.readString(),
        englishText: reader.readString(),
        confidence: reader.readInt(),
        confidenceLevel: reader.readString(),
        latencyMs: reader.readInt(),
        gloveTimestampMs: reader.readInt(),
        receivedAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
        corrected: reader.readBool(),
        originalWordId: reader.readBool() ? reader.readInt() : null,
        source: reader.readString(),
        appVersion: reader.readString(),
        modelVersion: reader.readString(),
      );
}

class SyncQueueEntryAdapter extends TypeAdapter<SyncQueueEntry> {
  final int typeId = 2;
  final int version = 1;

  @override
  void write(BinaryWriter writer, SyncQueueEntry e) {
    writer
      ..writeInt(e.id ?? 0)
      ..writeInt(e.logEntryId)
      ..writeInt(e.createdAt.millisecondsSinceEpoch);
  }

  @override
  SyncQueueEntry read(BinaryReader reader) => SyncQueueEntry(
        id: reader.readInt(),
        logEntryId: reader.readInt(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      );
}

class ParticipantProfileAdapter extends TypeAdapter<ParticipantProfile> {
  final int typeId = 3;
  final int version = 1;

  @override
  void write(BinaryWriter writer, ParticipantProfile p) {
    writer
      ..writeString(p.id)
      ..writeBool(p.consentGiven)
      ..writeBool(p.consentDate != null)
      ..writeInt(p.consentDate?.millisecondsSinceEpoch ?? 0)
      ..writeBool(p.isMinor);
  }

  @override
  ParticipantProfile read(BinaryReader reader) => ParticipantProfile(
        id: reader.readString(),
        consentGiven: reader.readBool(),
        consentDate: reader.readBool()
            ? DateTime.fromMillisecondsSinceEpoch(reader.readInt())
            : null,
        isMinor: reader.readBool(),
      );
}

class SessionMetaAdapter extends TypeAdapter<SessionMeta> {
  final int typeId = 4;
  final int version = 1;

  @override
  void write(BinaryWriter writer, SessionMeta s) {
    writer
      ..writeString(s.sessionId)
      ..writeString(s.participantId)
      ..writeInt(s.startedAt.millisecondsSinceEpoch);
  }

  @override
  SessionMeta read(BinaryReader reader) => SessionMeta(
        sessionId: reader.readString(),
        participantId: reader.readString(),
        startedAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      );
}
