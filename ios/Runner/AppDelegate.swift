import Flutter
import ImageIO
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    IOSVisionOCR.register(with: engineBridge.pluginRegistry)
  }
}

/// iOS 侧中文票据识别。
///
/// google_mlkit_text_recognition 在 iOS 上只有 Latin 模型，请求 chinese 会优雅回退，
/// 但中文会识别成乱码。Apple Vision 从 iOS 11 起支持 `zh-Hans`，且完全离线。
/// 这里把识别结果按屏幕阅读顺序（从上到下、从左到右）排好再回传，
/// 与 Dart 侧的票据字段解析器顺序保持一致。
private final class IOSVisionOCR {
  private static let channelName = "com.groot.assetmanager/ios_vision_ocr"

  static func register(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "IOSVisionOCR") else { return }
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "recognizeFile" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(FlutterError(
          code: "INVALID_ARGUMENT",
          message: "缺少图片路径",
          details: nil
        ))
        return
      }
      do {
        result(try recognize(path: path))
      } catch {
        result(FlutterError(
          code: "OCR_FAILED",
          message: error.localizedDescription,
          details: nil
        ))
      }
    }
  }

  private static func recognize(path: String) throws -> [String: Any] {
    guard let image = UIImage(contentsOfFile: path),
          let cgImage = image.cgImage else {
      throw NSError(
        domain: "IOSVisionOCR",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "无法读取图片，请重新选择"]
      )
    }

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["zh-Hans", "en-US"]

    let handler = VNImageRequestHandler(
      cgImage: cgImage,
      orientation: image.imageOrientation.cgImagePropertyOrientation,
      options: [:]
    )

    do {
      try handler.perform([request])
    } catch {
      // 少数系统语言包不完整时 zh-Hans 会失败，退回英文至少保住金额/日期。
      request.recognitionLanguages = ["en-US"]
      try handler.perform([request])
    }

    var lines: [[String: Any]] = []
    for observation in request.results ?? [] {
      guard let candidate = observation.topCandidates(1).first else { continue }
      let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
      if text.isEmpty { continue }
      lines.append([
        "text": text,
        "confidence": Double(candidate.confidence) as NSNumber,
        "minY": Double(observation.boundingBox.minY) as NSNumber,
        "minX": Double(observation.boundingBox.minX) as NSNumber,
      ])
    }

    lines.sort { left, right in
      let leftY = (left["minY"] as? NSNumber)?.doubleValue ?? 0
      let rightY = (right["minY"] as? NSNumber)?.doubleValue ?? 0
      if abs(leftY - rightY) > 0.005 { return leftY > rightY }
      let leftX = (left["minX"] as? NSNumber)?.doubleValue ?? 0
      let rightX = (right["minX"] as? NSNumber)?.doubleValue ?? 0
      return leftX < rightX
    }

    let cleaned = lines.map { line -> [String: Any] in
      var copy = line
      copy.removeValue(forKey: "minY")
      copy.removeValue(forKey: "minX")
      return copy
    }
    guard !cleaned.isEmpty else {
      throw NSError(
        domain: "IOSVisionOCR",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "未识别到文字，请换一张更清晰的图片"]
      )
    }

    let fullText = cleaned
      .compactMap { $0["text"] as? String }
      .joined(separator: "\n")
    return ["fullText": fullText, "lines": cleaned]
  }
}

private extension UIImage.Orientation {
  var cgImagePropertyOrientation: CGImagePropertyOrientation {
    switch self {
    case .up: return .up
    case .down: return .down
    case .left: return .left
    case .right: return .right
    case .upMirrored: return .upMirrored
    case .downMirrored: return .downMirrored
    case .leftMirrored: return .leftMirrored
    case .rightMirrored: return .rightMirrored
    @unknown default: return .up
    }
  }
}
