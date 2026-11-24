import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/ocr_result.dart';

/// 图片 OCR 识别：图片始终在本机处理，不上传。
///
/// - Android：ML Kit 中文模型（离线）。
/// - iOS：Apple Vision `VNRecognizeTextRequest`，指定 `zh-Hans`。
///   `google_mlkit_text_recognition` 在 iOS 上不提供中文模型，请求中文会回退到
///   Latin 识别器，中文票据会变成乱码，因此 iOS 走原生通道。
class OcrService {
  OcrService({
    TextRecognitionScript script = TextRecognitionScript.chinese,
    bool? useIOSVision,
  })  : _script = script,
        _useIOSVision = useIOSVision ?? Platform.isIOS;

  static const MethodChannel _visionChannel =
      MethodChannel('com.groot.assetmanager/ios_vision_ocr');

  final TextRecognitionScript _script;
  final bool _useIOSVision;
  TextRecognizer? _recognizer;

  TextRecognizer get _androidRecognizer =>
      _recognizer ??= TextRecognizer(script: _script);

  /// 识别失败（含无可读文字）抛出 [OcrException]，由调用方转成用户文案。
  Future<OCRRawResult> recognizeFile(String path) async {
    final recognized = _useIOSVision
        ? await _recognizeWithVision(path)
        : await _recognizeWithMlKit(path);

    final lines = <OCRLine>[];
    for (final line in recognized) {
      final text = line.text.trim();
      if (text.isEmpty) continue;
      lines.add(OCRLine(text: text, confidence: line.confidence));
    }
    if (lines.isEmpty) {
      throw const OcrException('未识别到文字，请换一张更清晰的图片');
    }

    return OCRRawResult(
      fullText: lines.map((line) => line.text).join('\n'),
      lines: lines,
    );
  }

  Future<List<_RecognizedLine>> _recognizeWithMlKit(String path) async {
    final input = InputImage.fromFilePath(path);
    final RecognizedText recognized;
    try {
      recognized = await _androidRecognizer.processImage(input);
    } catch (error) {
      throw OcrException('识别失败：$error');
    }
    final lines = <_RecognizedLine>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isEmpty) continue;
        // ML Kit 中文模型不一定返回置信度，缺省时用较高的经验值。
        lines.add(_RecognizedLine(text, line.confidence ?? 0.85));
      }
    }
    return lines;
  }

  Future<List<_RecognizedLine>> _recognizeWithVision(String path) async {
    final Map<Object?, Object?>? response;
    try {
      response = await OcrService._visionChannel
          .invokeMethod<Map<Object?, Object?>>('recognizeFile', <String, Object?>{'path': path});
    } on PlatformException catch (error) {
      throw OcrException('识别失败：${error.message ?? error.code}');
    } on MissingPluginException {
      throw const OcrException('当前版本未启用 iOS 中文识别，请重新安装应用');
    } catch (error) {
      throw OcrException('识别失败：$error');
    }

    if (response == null) {
      throw const OcrException('未识别到文字，请换一张更清晰的图片');
    }
    final rawLines = response['lines'];
    if (rawLines is! List) {
      throw const OcrException('识别结果格式异常');
    }
    final lines = <_RecognizedLine>[];
    for (final item in rawLines) {
      if (item is! Map) continue;
      final text = item['text']?.toString() ?? '';
      final confidence = item['confidence'];
      lines.add(_RecognizedLine(
        text,
        confidence is num ? confidence.toDouble() : 0.85,
      ));
    }
    // 原生侧已按「从上到下 / 从左到右」排好序，这里保留其顺序，
    // 让字段解析器读到的票据行序与屏幕上一致。
    return lines;
  }

  Future<void> dispose() async {
    final recognizer = _recognizer;
    _recognizer = null;
    if (recognizer != null) await recognizer.close();
  }
}

class _RecognizedLine {
  const _RecognizedLine(this.text, this.confidence);

  final String text;
  final double confidence;
}

class OcrException implements Exception {
  const OcrException(this.message);

  final String message;

  @override
  String toString() => message;
}
