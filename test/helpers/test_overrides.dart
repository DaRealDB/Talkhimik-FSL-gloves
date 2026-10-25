import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:talkhimik_app/application/providers.dart';
import 'package:talkhimik_app/data/glove/glove_connection.dart';
import 'package:talkhimik_app/data/glove/mock_glove_connection.dart';
import 'package:talkhimik_app/data/storage/calinfo_cache.dart';
import 'package:talkhimik_app/data/storage/settings_service.dart';
import 'package:talkhimik_app/data/tts/tts_service.dart';
import 'package:talkhimik_app/domain/repositories/log_store.dart';

import 'fake_tts_service.dart';
import 'in_memory_calinfo_cache.dart';
import 'in_memory_log_store.dart';
import 'in_memory_settings_service.dart';

/// Canned provider overrides for widget/integration tests. By default:
/// zero-delay mock glove, fake TTS, in-memory log store, in-memory
/// settings — nothing touches disk, wall-clock time, or plugins.
List<Override> testOverrides({
  GloveConnection? glove,
  LogStore? logStore,
  TtsService? tts,
  SettingsService? settings,
  CalInfoCache? calInfoCache,
  bool? gloveIsMock,
}) =>
    [
      gloveConnectionProvider.overrideWithValue(
        glove ??
            MockGloveConnection(
              config: const MockGloveConfig(
                connectStepDelay: Duration.zero,
                gestureCadence: Duration(milliseconds: 10),
              ),
            ),
      ),
      gloveIsMockProvider.overrideWithValue(gloveIsMock ?? true),
      logStoreProvider.overrideWithValue(logStore ?? InMemoryLogStore()),
      ttsServiceProvider.overrideWithValue(tts ?? FakeTtsService()),
      settingsServiceProvider
          .overrideWithValue(settings ?? InMemorySettingsService()),
      calInfoCacheProvider.overrideWithValue(
          calInfoCache ?? InMemoryCalInfoCache()),
    ];
