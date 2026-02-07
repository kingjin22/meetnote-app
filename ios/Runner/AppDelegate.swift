import AVFoundation
import Flutter
import Speech
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let transcriptionChannelName = "meetnote/transcription"
  private var activeRecognizer: SFSpeechRecognizer?
  private var activeRecognitionTask: SFSpeechRecognitionTask?
  private let defaultLocaleIdentifier = "ko-KR"

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

    let localeIdentifier = (args["locale"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let resolvedLocaleIdentifier = (localeIdentifier?.isEmpty == false)
      ? localeIdentifier!
      : defaultLocaleIdentifier
    let allowOnlineFallback = (args["allowOnlineFallback"] as? Bool) ?? true

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

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: resolvedLocaleIdentifier)) else {
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
        print("Transcription file extension: \(url.pathExtension.lowercased())")
        print("Transcription allow online fallback: \(allowOnlineFallback)")

        let prefersOnDevice = recognizer.supportsOnDeviceRecognition
        var didRespond = false

        func finalizeResponse(_ response: @escaping () -> Void, tempURL: URL?) {
          if didRespond {
            return
          }
          didRespond = true
          self.activeRecognitionTask = nil
          if let tempURL = tempURL {
            try? FileManager.default.removeItem(at: tempURL)
            print("Transcription temp file cleaned: \(tempURL.lastPathComponent)")
          }
          response()
        }

        func startRecognition(requiresOnDevice: Bool, audioURL: URL, tempURL: URL?) {
          self.activeRecognitionTask?.cancel()
          self.activeRecognitionTask = nil
          self.activeRecognizer = recognizer

          let request = SFSpeechURLRecognitionRequest(url: audioURL)
          request.shouldReportPartialResults = false
          request.requiresOnDeviceRecognition = requiresOnDevice

          let mode = requiresOnDevice ? "on-device" : "online"
          print("Transcription recognition mode: \(mode)")
          if audioURL != url {
            print("Transcription using transcoded file: \(audioURL.lastPathComponent)")
          }

          self.activeRecognitionTask = recognizer.recognitionTask(with: request) { transcription, error in
            if let error = error {
              if requiresOnDevice, allowOnlineFallback {
                print("Transcription on-device error, retrying online: \(error.localizedDescription)")
                startRecognition(requiresOnDevice: false, audioURL: audioURL, tempURL: tempURL)
                return
              }
              finalizeResponse({
                result(FlutterError(
                  code: "transcription_failed",
                  message: "텍스트 변환에 실패했어요: \(error.localizedDescription)",
                  details: nil
                ))
              }, tempURL: tempURL)
              return
            }

            guard let transcription = transcription else {
              return
            }

            if transcription.isFinal {
              let formattedText = transcription.bestTranscription.formattedString
                .trimmingCharacters(in: .whitespacesAndNewlines)
              if formattedText.isEmpty {
                if requiresOnDevice, allowOnlineFallback {
                  print("Transcription on-device empty, retrying online.")
                  startRecognition(requiresOnDevice: false, audioURL: audioURL, tempURL: tempURL)
                  return
                }
                finalizeResponse({
                  result(FlutterError(
                    code: "empty_transcript",
                    message: "텍스트 변환 결과가 비어 있어요. 녹음을 확인하거나 다시 시도해주세요.",
                    details: nil
                  ))
                }, tempURL: tempURL)
                return
              }
              finalizeResponse({
                result(formattedText)
              }, tempURL: tempURL)
            }
          }
        }

        self.prepareAudioForRecognition(from: url) { preparedURL, tempURL in
          DispatchQueue.main.async {
            startRecognition(requiresOnDevice: prefersOnDevice, audioURL: preparedURL, tempURL: tempURL)
          }
        }
      }
    }
  }

  private func prepareAudioForRecognition(
    from url: URL,
    completion: @escaping (URL, URL?) -> Void
  ) {
    let extensionLowercased = url.pathExtension.lowercased()
    let speechFriendlyExtensions: Set<String> = ["m4a", "caf", "wav", "aif", "aiff"]
    guard !speechFriendlyExtensions.contains(extensionLowercased) else {
      completion(url, nil)
      return
    }

    let asset = AVURLAsset(url: url)
    let preset = AVAssetExportPresetAppleM4A
    let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: asset)
    guard compatiblePresets.contains(preset) else {
      print("Transcription export preset not compatible, skipping transcode.")
      completion(url, nil)
      return
    }

    guard let exportSession = AVAssetExportSession(asset: asset, presetName: preset) else {
      print("Transcription export session could not be created, skipping transcode.")
      completion(url, nil)
      return
    }

    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("m4a")

    exportSession.outputURL = tempURL
    exportSession.outputFileType = .m4a
    exportSession.shouldOptimizeForNetworkUse = false

    print("Transcription export started: \(tempURL.lastPathComponent)")

    exportSession.exportAsynchronously { [weak exportSession] in
      let status = exportSession?.status ?? .unknown
      let errorDescription = exportSession?.error?.localizedDescription ?? "none"
      print("Transcription export status: \(status.rawValue), error: \(errorDescription)")

      guard status == .completed else {
        if FileManager.default.fileExists(atPath: tempURL.path) {
          try? FileManager.default.removeItem(at: tempURL)
        }
        completion(url, nil)
        return
      }

      completion(tempURL, tempURL)
    }
  }
}
