import 'package:talkhimik_app/data/storage/calibration_store.dart';
import 'package:talkhimik_app/domain/models/calibration_profile.dart';

/// In-memory [CalibrationProfileStore] — widget/unit tests use this so
/// nothing touches shared_preferences.
class InMemoryCalibrationProfileStore implements CalibrationProfileStore {
  CalibrationProfile? saved;

  @override
  Future<CalibrationProfile?> load() async => saved;

  @override
  Future<void> save(CalibrationProfile profile) async => saved = profile;
}
