import Flutter
import Speech
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let transcriptionChannelName = "meetnote/transcription"
  private var activeRecognizer: SFSpeechRecognizer?
  private var activeRecognitionTask: SFSpeechRecognitionTask?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: transcriptionChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "transcribeFile" else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.handleTranscribe(call: call, result: result)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handleTranscribe(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String else {
      result(FlutterError(code: "bad_args", message: "파일 경로가 없어요.", details: nil))
      return
    }

    let url = URL(fileURLWithPath: path)
    if !FileManager.default.fileExists(atPath: url.path) {
      result(FlutterError(code: "file_missing", message: "오디오 파일을 찾을 수 없어요.", details: nil))
      return
    }

    SFSpeechRecognizer.requestAuthorization { status in
      DispatchQueue.main.async {
        guard status == .authorized else {
          result(FlutterError(
            code: "speech_denied",
            message: "음성 인식 권한이 필요해요.",
            details: nil
          ))
          return
        }

        guard let recognizer = SFSpeechRecognizer() else {
          result(FlutterError(
            code: "recognizer_unavailable",
            message: "음성 인식을 사용할 수 없어요.",
            details: nil
          ))
          return
        }

        if !recognizer.isAvailable {
          result(FlutterError(
            code: "recognizer_busy",
            message: "음성 인식이 잠시 후에 가능해요.",
            details: nil
          ))
          return
        }

        if !recognizer.supportsOnDeviceRecognition {
          result(FlutterError(
            code: "offline_unavailable",
            message: "이 기기에서는 오프라인 음성 인식을 지원하지 않아요.",
            details: nil
          ))
          return
        }

        self.activeRecognitionTask?.cancel()
        self.activeRecognitionTask = nil
        self.activeRecognizer = recognizer

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = true

        var didRespond = false
        self.activeRecognitionTask = recognizer.recognitionTask(with: request) { transcription, error in
          if didRespond {
            return
          }

          if let error = error {
            didRespond = true
            self.activeRecognitionTask = nil
            result(FlutterError(
              code: "transcription_failed",
              message: "텍스트 변환에 실패했어요: \(error.localizedDescription)",
              details: nil
            ))
            return
          }

          guard let transcription = transcription else {
            return
          }

          if transcription.isFinal {
            didRespond = true
            self.activeRecognitionTask = nil
            result(transcription.bestTranscription.formattedString)
          }
        }
      }
    }
  }
}
