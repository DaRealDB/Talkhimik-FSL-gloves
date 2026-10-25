import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Runs before every test file: gives the DEFAULT settings provider
/// (SharedPrefsSettingsService) an in-memory platform, so tests that read
/// providers transitively (e.g. forceMockProvider → settings) never hit the
/// missing-platform error. Tests that override the settings provider are
/// unaffected.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  await testMain();
}
