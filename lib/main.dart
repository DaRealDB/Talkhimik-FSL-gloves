import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'application/providers.dart';
import 'data/glove/glove_connection_factory.dart';
import 'data/storage/hive_log_store.dart';
import 'data/storage/settings_service.dart';
import 'domain/models/telemetry_packet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local persistence (FR-10): Hive boxes for events, the sync queue,
  // participants, and sessions. Pure Dart — same behavior on Windows and
  // Android field devices. On web Hive uses IndexedDB and ignores the path
  // (path_provider has no web implementation), so skip the lookup there.
  final appDir = kIsWeb ? '' : (await getApplicationSupportDirectory()).path;
  Hive.init(appDir);
  final logStore = HiveLogStore(Hive);
  await logStore.init();

  // FR field-testing aid: the "Force mock" setting swaps the connection at
  // startup (the real BLE client is Android-only anyway). One connection
  // per glove (master §7.3): the keep-area primary is the LEFT hand.
  final settingsService = SharedPrefsSettingsService();
  final forceMock = await settingsService.forceMock();
  final glove = GloveConnectionFactory.create(forceMock: forceMock);
  final rightGlove = GloveConnectionFactory.createForHand(GloveHand.right,
      forceMock: forceMock);

  final container = ProviderContainer(
    overrides: [
      logStoreProvider.overrideWithValue(logStore),
      gloveConnectionProvider.overrideWithValue(glove),
      rightGloveConnectionProvider.overrideWithValue(rightGlove),
    ],
  );
  runApp(UncontrolledProviderScope(container: container, child: const TalkhimikApp()));

  // Load TTS settings and initialize the engine without blocking startup.
  container.read(ttsControllerProvider.notifier).initialize();
}
