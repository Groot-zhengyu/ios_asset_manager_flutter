import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ios_asset_manager_flutter/services/ocr_service.dart';

const _channel = MethodChannel('com.groot.assetmanager/ios_vision_ocr');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('iOS 通道把 Vision 的中文行按原生顺序转成 OCRRawResult', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      expect(call.method, 'recognizeFile');
      expect(call.arguments, {'path': '/tmp/receipt.png'});
      return {
        'fullText': '中国石化\n加油 300.00\n2026-11-20',
        'lines': [
          {'text': '中国石化', 'confidence': 0.91},
          {'text': '加油 300.00', 'confidence': 0.88},
          {'text': '2026-11-20', 'confidence': 0.95},
        ],
      };
    });

    final service = OcrService(useIOSVision: true);
    final raw = await service.recognizeFile('/tmp/receipt.png');

    expect(raw.lines.map((line) => line.text).toList(), [
      '中国石化',
      '加油 300.00',
      '2026-11-20',
    ]);
    expect(raw.fullText, '中国石化\n加油 300.00\n2026-11-20');
    expect(raw.lines.first.confidence, 0.91);
    expect(raw.averageConfidence, closeTo(0.913, 0.001));
    await service.dispose();
  });

  test('iOS 通道返回空结果时抛出可读错误', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      return {'fullText': '', 'lines': []};
    });

    final service = OcrService(useIOSVision: true);
    await expectLater(
      service.recognizeFile('/tmp/blank.png'),
      throwsA(
        isA<OcrException>().having(
          (error) => error.message,
          'message',
          contains('未识别到文字'),
        ),
      ),
    );
  });

  test('iOS 原生异常转成 OcrException，不会把 PlatformException 抛给界面', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      throw PlatformException(
        code: 'OCR_FAILED',
        message: '无法读取图片，请重新选择',
      );
    });

    final service = OcrService(useIOSVision: true);
    await expectLater(
      service.recognizeFile('/tmp/missing.png'),
      throwsA(
        isA<OcrException>().having(
          (error) => error.message,
          'message',
          contains('无法读取图片'),
        ),
      ),
    );
  });
}
