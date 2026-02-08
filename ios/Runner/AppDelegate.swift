import AVFoundation
import Flutter
import Speech
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let transcriptionChannelName = "meetnote/transcription"
  private let transcriptionEventChannelName = "meetnote/transcription_progress"
  private var transcriptionService: TranscriptionService?
  private var progressEventSink: FlutterEventSink?
  private let defaultLocaleIdentifier = "ko-KR"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // Method Channel
    let methodChannel = FlutterMethodChannel(
      name: transcriptionChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    methodChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "transcribeFile" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.handleTranscribe(call: call, result: result)
    }
    
    // Event Channel for progress
    let eventChannel = FlutterEventChannel(
      name: transcriptionEventChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    eventChannel.setStreamHandler(self)
    
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

    let localeIdentifier = (args["locale"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let resolvedLocaleIdentifier = (localeIdentifier?.isEmpty == false)
      ? localeIdentifier!
      : defaultLocaleIdentifier
    let allowOnlineFallback = (args["allowOnlineFallback"] as? Bool) ?? true

    SFSpeechRecognizer.requestAuthorization { [weak self] status in
      guard let self = self else { return }
      
      DispatchQueue.main.async {
        guard status == .authorized else {
          result(FlutterError(
            code: "speech_denied",
            message: "음성 인식 권한이 필요해요.",
            details: nil
          ))
          return
        }

        // Create transcription service
        let service = TranscriptionService()
        self.transcriptionService = service
        
        // Start transcription with progress
        service.transcribeFile(
          url: url,
          locale: Locale(identifier: resolvedLocaleIdentifier),
          allowOnlineFallback: allowOnlineFallback,
          onProgress: { [weak self] progress in
            // Send progress to Flutter via EventChannel
            self?.progressEventSink?([
              "totalChunks": progress.totalChunks,
              "completedChunks": progress.completedChunks,
              "currentChunk": progress.currentChunk,
              "percentage": progress.percentage
            ])
          },
          completion: { [weak self] transcriptionResult in
            self?.transcriptionService = nil
            
            switch transcriptionResult {
            case .success(let text):
              result(text)
            case .failure(let error):
              let nsError = error as NSError
              result(FlutterError(
                code: "transcription_failed",
                message: error.localizedDescription,
                details: nil
              ))
            }
          }
        )
      }
    }
  }
}

// MARK: - FlutterStreamHandler
extension AppDelegate: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    progressEventSink = events
    return nil
  }
  
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    progressEventSink = nil
    return nil
  }
}
