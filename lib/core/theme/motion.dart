import 'package:flutter/material.dart';

/// Motion tokens (typography & motion pass). All durations/curves live
/// here — no ad-hoc literals in widgets. `reduce-motion` (MediaQuery
/// accessibility) zeroes every duration through [of]/[resolve].
@immutable
class TalkhimikMotion extends ThemeExtension<TalkhimikMotion> {
  const TalkhimikMotion({
    required this.instant,
    required this.quick,
    required this.standard,
    required this.emphasized,
    required this.standardCurve,
    required this.enterCurve,
    required this.exitCurve,
    required this.emphasizedCurve,
    required this.successCurve,
  });

  final Duration instant; // 100 ms
  final Duration quick; // 180 ms
  final Duration standard; // 280 ms
  final Duration emphasized; // 420 ms

  final Curve standardCurve; // easeOutCubic
  final Curve enterCurve; // easeOut
  final Curve exitCurve; // easeIn
  final Curve emphasizedCurve; // easeInOutCubicEmphasized
  final Curve successCurve; // elasticOut — one-shot success moments

  static const values = TalkhimikMotion(
    instant: Duration(milliseconds: 100),
    quick: Duration(milliseconds: 180),
    standard: Duration(milliseconds: 280),
    emphasized: Duration(milliseconds: 420),
    standardCurve: Curves.easeOutCubic,
    enterCurve: Curves.easeOut,
    exitCurve: Curves.easeIn,
    emphasizedCurve: Curves.easeInOutCubicEmphasized,
    successCurve: Curves.elasticOut,
  );

  static TalkhimikMotion of(BuildContext context) =>
      Theme.of(context).extension<TalkhimikMotion>() ?? values;

  /// [duration] zeroed when the user asked for reduced motion.
  Duration resolve(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;

  @override
  TalkhimikMotion copyWith({
    Duration? instant,
    Duration? quick,
    Duration? standard,
    Duration? emphasized,
    Curve? standardCurve,
    Curve? enterCurve,
    Curve? exitCurve,
    Curve? emphasizedCurve,
    Curve? successCurve,
  }) =>
      TalkhimikMotion(
        instant: instant ?? this.instant,
        quick: quick ?? this.quick,
        standard: standard ?? this.standard,
        emphasized: emphasized ?? this.emphasized,
        standardCurve: standardCurve ?? this.standardCurve,
        enterCurve: enterCurve ?? this.enterCurve,
        exitCurve: exitCurve ?? this.exitCurve,
        emphasizedCurve: emphasizedCurve ?? this.emphasizedCurve,
        successCurve: successCurve ?? this.successCurve,
      );

  @override
  TalkhimikMotion lerp(TalkhimikMotion? other, double t) => this;
}
