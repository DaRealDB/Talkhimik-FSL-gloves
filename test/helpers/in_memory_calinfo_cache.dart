import 'package:talkhimik_app/data/storage/calinfo_cache.dart';
import 'package:talkhimik_app/domain/models/cal_info_packet.dart';
import 'package:talkhimik_app/domain/models/telemetry_packet.dart';

/// In-memory [CalInfoCache] for tests — nothing touches shared_preferences.
class InMemoryCalInfoCache implements CalInfoCache {
  final Map<GloveHand, CalInfoPacket> saved = {};

  @override
  Future<CalInfoPacket?> load(GloveHand hand) async => saved[hand];

  @override
  Future<void> save(GloveHand hand, CalInfoPacket packet) async =>
      saved[hand] = packet;
}
