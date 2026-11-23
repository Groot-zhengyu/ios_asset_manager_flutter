import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/ocr_result.dart';

/// 图片 OCR 识别：调用设备本地的 ML Kit 中文文本识别模型（离线、不上传图片）。
class OcrService {
  OcrService({TextRecognitionScript script = TextRecognitionScript.chinese})
      : _recognizer = TextRecognizer(script: script);

  final TextRecognizer _recognizer;

  /// 识别失败（含无可读文字）抛出 [OcrException]，由调用方转成用户文案。
  Future<OCRRawResult> recognizeFile(String path) async {
    final input = InputImage.fromFilePath(path);
    final RecognizedText recognized;
    try {
      recognized = await _recognizer.processImage(input);
    } catch (error) {
      throw OcrException('识别失败：$error');
    }

    final lines = <OCRLine>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isEmpty) continue;
        // ML Kit 中文模型不一定返回置信度，缺省时用较高的经验值。
        final confidence = line.confidence ?? 0.85;
        lines.add(OCRLine(text: text, confidence: confidence));
      }
    }
    if (lines.isEmpty) {
      throw const OcrException('未识别到文字，请换一张更清晰的图片');
    }

    return OCRRawResult(
      fullText: lines.map((line) => line.text).join('\n'),
      lines: lines,
    );
  }

  Future<void> dispose() => _recognizer.close();
}

class OcrException implements Exception {
  const OcrException(this.message);

  final String message;

  @override
  String toString() => message;
}
