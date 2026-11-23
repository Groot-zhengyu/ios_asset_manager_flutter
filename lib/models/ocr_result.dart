import '../core/decimal.dart';
import 'enums.dart';

class OCRLine {
  final String text;
  final double confidence;

  OCRLine({required this.text, this.confidence = 0});
}

class OCRRawResult {
  final String fullText;
  final List<OCRLine> lines;

  OCRRawResult({required this.fullText, required this.lines});

  double get averageConfidence => lines.isEmpty
      ? 0
      : lines.fold<double>(0, (sum, line) => sum + line.confidence) /
          lines.length;
}

class OCRStructuredResult {
  final ExpenseType? type;
  final Dec? amount;
  final DateTime? date;
  final String? note;
  final double confidence;
  final String rawText;

  OCRStructuredResult({
    this.type,
    this.amount,
    this.date,
    this.note,
    required this.confidence,
    required this.rawText,
  });
}
