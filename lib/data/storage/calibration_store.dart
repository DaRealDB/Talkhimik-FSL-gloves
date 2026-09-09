import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/calibration_profile.dart';

/// Persistence for the per-user calibration profile (SRS FR-8).
///
/// One profile at a time (the current signer); a re-run overwrites it.
/// Backed by shared_preferences as a JSON string, like the other small
/// settings — no Hive adapter needed.
abstract interface class CalibrationProfileStore {
  Future<CalibrationProfile?> load();

  Future<void> save(CalibrationProfile profile);
}

class SharedPrefsCalibrationProfileStore implements CalibrationProfileStore {
  SharedPrefsCalibrationProfileStore([SharedPreferencesAsync? prefs])
      : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _kProfile = 'calibration.profile';

  @override
  Future<CalibrationProfile?> load() async {
    final raw = await _prefs.getString(_kProfile);
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, Object?>;
    return CalibrationProfile.fromJson(json);
  }

  @override
  Future<void> save(CalibrationProfile profile) =>
      _prefs.setString(_kProfile, jsonEncode(profile.toJson()));
}
