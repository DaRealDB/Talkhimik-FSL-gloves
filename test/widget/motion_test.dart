import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/core/theme/app_theme.dart';
import 'package:talkhimik_app/core/theme/motion.dart';

void main() {
  testWidgets('reduce-motion zeroes every duration via resolve',
      (tester) async {
    late Duration resolved;
    await tester.pumpWidget(MaterialApp(
      theme: buildLightTheme(),
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(builder: (context) {
          final motion = TalkhimikMotion.of(context);
          resolved = motion.resolve(context, motion.standard);
          return const SizedBox();
        }),
      ),
    ));
    await tester.pump();
    expect(resolved, Duration.zero);
  });

  testWidgets('durations pass through when animations are enabled',
      (tester) async {
    late Duration resolved;
    await tester.pumpWidget(MaterialApp(
      theme: buildLightTheme(),
      home: Builder(builder: (context) {
        final motion = TalkhimikMotion.of(context);
        resolved = motion.resolve(context, motion.quick);
        return const SizedBox();
      }),
    ));
    await tester.pump();
    expect(resolved, TalkhimikMotion.values.quick);
  });

  test('motion token values match the approved scale', () {
    const m = TalkhimikMotion.values;
    expect(m.instant, const Duration(milliseconds: 100));
    expect(m.quick, const Duration(milliseconds: 180));
    expect(m.standard, const Duration(milliseconds: 280));
    expect(m.emphasized, const Duration(milliseconds: 420));
    expect(m.standardCurve, Curves.easeOutCubic);
    expect(m.successCurve, Curves.elasticOut);
  });
}
