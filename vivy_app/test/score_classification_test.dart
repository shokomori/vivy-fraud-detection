import 'package:flutter_test/flutter_test.dart';
import 'package:vivy_app/main.dart';

void main() {
  group('classifyReceiptScore', () {
    test('treats low genuine scores as genuine', () {
      final decision = classifyReceiptScore(0.08);

      expect(decision.isFraudulent, isFalse);
      expect(decision.confidence, closeTo(0.92, 1e-9));
    });

    test('treats scores at the threshold as fraudulent', () {
      final decision = classifyReceiptScore(0.16);

      expect(decision.isFraudulent, isTrue);
    });

    test('treats scores above the threshold as fraudulent', () {
      final decision = classifyReceiptScore(0.2);

      expect(decision.isFraudulent, isTrue);
    });

    test('marks scores within the invalid band as ambiguous', () {
      final score = 0.16;
      expect(score >= kInvalidBandLow, isTrue);
      expect(score <= kInvalidBandHigh, isTrue);
    });
  });
}
