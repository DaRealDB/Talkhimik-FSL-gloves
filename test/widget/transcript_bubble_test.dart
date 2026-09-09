import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/core/constants/confidence.dart';
import 'package:talkhimik_app/core/theme/app_theme.dart';
import 'package:talkhimik_app/domain/models/transcript_entry.dart';
import 'package:talkhimik_app/ui/widgets/confidence_badge.dart';
import 'package:talkhimik_app/ui/widgets/transcript_bubble.dart';

TranscriptEntry signedEntry({
  int id = 1,
  int confidence = 95,
  ConfidenceLevel? level,
  bool corrected = false,
}) =>
    TranscriptEntry(
      id: id,
      kind: TranscriptKind.signed,
      filipino: 'Salamat',
      english: 'Thank you',
      wordId: 104,
      confidence: confidence,
      confidenceLevel: level ?? ConfidenceThresholds.levelFor(confidence),
      corrected: corrected,
      originalWordId: corrected ? 104 : null,
    );

Widget wrap(TranscriptEntry entry, {bool largeText = true}) => MaterialApp(
      home: Scaffold(
        body: TranscriptBubble(
          entry: entry,
          language: 'fil',
          largeText: largeText,
        ),
      ),
    );

void main() {
  testWidgets('renders the Filipino text and a confidence badge',
      (tester) async {
    await tester.pumpWidget(wrap(signedEntry(confidence: 95)));
    expect(find.text('Salamat'), findsOneWidget);
    expect(find.text('95%'), findsOneWidget);
  });

  testWidgets('renders the English variant when language is en',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TranscriptBubble(
          entry: signedEntry(),
          language: 'en',
          largeText: true,
        ),
      ),
    ));
    expect(find.text('Thank you'), findsOneWidget);
  });

  test('badge color mapping is green/amber/red (FR-4)', () {
    expect(ConfidenceBadge.colorFor(ConfidenceLevel.high),
        AppColors.confidenceGreen);
    expect(ConfidenceBadge.colorFor(ConfidenceLevel.medium),
        AppColors.confidenceAmber);
    expect(ConfidenceBadge.colorFor(ConfidenceLevel.low),
        AppColors.confidenceRed);
  });

  testWidgets('shows the corrected marker', (tester) async {
    await tester.pumpWidget(wrap(signedEntry(corrected: true)));
    expect(find.text('corrected'), findsOneWidget);
  });

  testWidgets('partner bubbles render large signer-facing text (FR-7)',
      (tester) async {
    final entry = TranscriptEntry(
      id: 2,
      kind: TranscriptKind.partner,
      filipino: 'Kumusta ka na?',
      english: 'Kumusta ka na?',
      source: 'partner',
    );
    await tester.pumpWidget(wrap(entry));
    final text = tester.widget<Text>(find.text('Kumusta ka na?'));
    expect(text.style?.fontSize, 22);
  });

  testWidgets('partner text respects the large-text toggle', (tester) async {
    final entry = TranscriptEntry(
      id: 2,
      kind: TranscriptKind.partner,
      filipino: 'Kumusta ka na?',
      english: 'Kumusta ka na?',
      source: 'partner',
    );
    await tester.pumpWidget(wrap(entry, largeText: false));
    final text = tester.widget<Text>(find.text('Kumusta ka na?'));
    expect(text.style?.fontSize, 16);
  });
}
