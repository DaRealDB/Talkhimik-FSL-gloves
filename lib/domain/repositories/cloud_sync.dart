import 'log_store.dart';

/// Cloud-side responsibilities deferred to the Firebase pass (SRS C-S4,
/// FR-14, D4). The local-only implementation of this pass keeps the app
/// fully functional offline: the queue flushes trivially and the model
/// registry reports nothing newer.
abstract interface class CloudSync {
  /// Uploads pending queue entries. The local implementation marks them
  /// synced without uploading.
  Future<void> flushQueue(LogStore store);

  /// FR-14: newest approved model from the Firebase model registry.
  /// Returns null when offline or when no registry exists yet.
  Future<ModelVersionInfo?> checkLatestModelVersion();
}

/// What the FR-14 registry would report. Stub type until Firebase exists.
class ModelVersionInfo {
  const ModelVersionInfo({required this.version, required this.assetUrl});

  final String version;
  final String assetUrl;
}
