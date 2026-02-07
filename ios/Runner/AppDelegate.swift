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

        print("Transcription recognizer locale: \(recognizer.locale.identifier)")
        print("Transcription file URL: \(url.absoluteString)")

        let prefersOnDevice = recognizer.supportsOnDeviceRecognition
        var didRespond = false

        func startRecognition(requiresOnDevice: Bool) {
          self.activeRecognitionTask?.cancel()
          self.activeRecognitionTask = nil
          self.activeRecognizer = recognizer

          let request = SFSpeechURLRecognitionRequest(url: url)
          request.shouldReportPartialResults = false
          request.requiresOnDeviceRecognition = requiresOnDevice

          let mode = requiresOnDevice ? "on-device" : "online"
          print("Transcription recognition mode: \(mode)")

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
              let formattedText = transcription.bestTranscription.formattedString
                .trimmingCharacters(in: .whitespacesAndNewlines)
              if formattedText.isEmpty {
                if requiresOnDevice {
                  startRecognition(requiresOnDevice: false)
                  return
                }
                didRespond = true
                self.activeRecognitionTask = nil
                result(FlutterError(
                  code: "empty_transcript",
                  message: "텍스트 변환 결과가 비어 있어요. 녹음을 확인하거나 다시 시도해주세요.",
                  details: nil
                ))
                return
              }
              didRespond = true
              self.activeRecognitionTask = nil
              result(formattedText)
            }
          }
        }

        startRecognition(requiresOnDevice: prefersOnDevice)
      }
    }
  }
}
