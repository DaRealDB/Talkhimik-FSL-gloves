import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/cal_info_packet.dart';
import '../../domain/models/telemetry_packet.dart';

/// Last-known CAL_INFO mirror per hand (master §4.5). The glove's NVS is the
/// calibration authority; this cache only shows the last profile while the
/// glove is disconnected and feeds dataset sidecars. Never a source of truth.
abstract interface class CalInfoCache {
  Future<CalInfoPacket?> load(GloveHand hand);

  Future<void> save(GloveHand hand, CalInfoPacket packet);
}

/// shared_preferences JSON, like the other small settings — pure Dart.
class SharedPrefsCalInfoCache implements CalInfoCache {
  SharedPrefsCalInfoCache([SharedPreferencesAsync? prefs])
      : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static String _key(GloveHand hand) =>
      'calinfo.${hand == GloveHand.left ? 'L' : 'R'}';

  @override
  Future<CalInfoPacket?> load(GloveHand hand) async {
    final raw = await _prefs.getString(_key(hand));
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, Object?>;
    return CalInfoPacket.fromJson(json);
  }

  @override
  Future<void> save(GloveHand hand, CalInfoPacket packet) =>
      _prefs.setString(_key(hand), jsonEncode(packet.toJson()));
}
