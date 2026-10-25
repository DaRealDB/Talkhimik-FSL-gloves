import 'package:meta/meta.dart';

import 'cal_info_packet.dart';
import 'device_status.dart';
import 'telemetry_packet.dart';

/// Live snapshot of ONE glove: the latest contract packets plus the
/// connection-health counters the Live screen derives from them (§6.1).
@immutable
class HandState {
  const HandState({
    required this.hand,
    this.telemetry,
    this.status,
    this.calInfo,
    this.receivedFrames = 0,
    this.lostFrames = 0,
    this.lastFrameAt,
  });

  /// Which glove this state tracks; the telemetry `hand` byte must agree
  /// (a mismatch is surfaced as a warning, master §7.3).
  final GloveHand hand;

  final TelemetryPacket? telemetry;
  final DeviceStatusPacket? status;
  final CalInfoPacket? calInfo;

  /// Total frames ever received — the packet-loss % denominator.
  final int receivedFrames;

  /// Frames lost, accumulated from wrap-safe seq gaps.
  final int lostFrames;

  /// Phone clock at the last telemetry frame (freshness source).
  final DateTime? lastFrameAt;

  bool get uncalibrated => status?.uncalibrated ?? false;

  double get packetLossPercent =>
      receivedFrames == 0 ? 0 : lostFrames * 100 / receivedFrames;

  /// Stale per §6.1: no frame within the last 500 ms.
  bool isStaleAt(DateTime now) =>
      lastFrameAt == null ||
      now.difference(lastFrameAt!) > const Duration(milliseconds: 500);

  HandState copyWith({
    GloveHand? hand,
    TelemetryPacket? telemetry,
    DeviceStatusPacket? status,
    CalInfoPacket? calInfo,
    int? receivedFrames,
    int? lostFrames,
    DateTime? lastFrameAt,
  }) =>
      HandState(
        hand: hand ?? this.hand,
        telemetry: telemetry ?? this.telemetry,
        status: status ?? this.status,
        calInfo: calInfo ?? this.calInfo,
        receivedFrames: receivedFrames ?? this.receivedFrames,
        lostFrames: lostFrames ?? this.lostFrames,
        lastFrameAt: lastFrameAt ?? this.lastFrameAt,
      );
}
