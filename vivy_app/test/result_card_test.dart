import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivy_app/domain/analysis_models.dart';
import 'package:vivy_app/ui/widgets/result_card.dart';

void main() {
  testWidgets('renders genuine and fraudulent cards without unclear state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                ResultCard(
                  result: AnalysisResult.classified(
                    isFraudulent: false,
                    score: 0.08,
                    confidence: 0.92,
                    explanation: 'Looks genuine.',
                  ),
                  threshold: 0.16,
                ),
                const SizedBox(height: 12),
                ResultCard(
                  result: AnalysisResult.invalid(
                    message: 'Could not verify this image.',
                    score: 0.16,
                    confidence: 0.0,
                    explanation: 'This sample is ambiguous and should be retaken.',
                  ),
                  threshold: 0.16,
                ),
                const SizedBox(height: 12),
                ResultCard(
                  result: AnalysisResult.classified(
                    isFraudulent: true,
                    score: 0.2,
                    confidence: 0.8,
                    explanation: 'Looks fraudulent.',
                  ),
                  threshold: 0.16,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Genuine'), findsOneWidget);
    expect(find.text('Invalid'), findsOneWidget);
    expect(find.text('Fraudulent'), findsOneWidget);
  });
}
