import 'package:meta/meta.dart';

/// Anonymized participant profile (SRS FR-13, DR-4).
///
/// Only an id, consent state, and the bare minimum study metadata are
/// stored — never names, photos, or identifying details (M4, NFR-8).
@immutable
class ParticipantProfile {
  const ParticipantProfile({
    required this.id,
    required this.consentGiven,
    this.consentDate,
    this.isMinor = false,
  });

  final String id;

  /// True only after the participant (or guardian, for minors) consented.
  /// Data collection is blocked until this is set (FR-13, M4).
  final bool consentGiven;

  /// When consent was recorded; null while pending.
  final DateTime? consentDate;

  /// Minors require parental consent per M4.
  final bool isMinor;
}
