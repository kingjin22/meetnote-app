import AVFoundation
import Speech
import Foundation

class TranscriptionService {
  private let maxConcurrentTasks = 4
  private let chunkDuration: TimeInterval = 30.0 // 30초 청크
  private var activeRecognizers: [SFSpeechRecognizer] = []
  private var activeTasks: [SFSpeechRecognitionTask] = []
  
  struct TranscriptionProgress {
    let totalChunks: Int
    let completedChunks: Int
    let currentChunk: Int
    
    var percentage: Double {
      totalChunks > 0 ? Double(completedChunks) / Double(totalChunks) : 0.0
    }
  }
  
  struct TranscriptionResult {
    let text: String
    let error: Error?
  }
  
  func transcribeFile(
    url: URL,
    locale: Locale,
    allowOnlineFallback: Bool,
    onProgress: @escaping (TranscriptionProgress) -> Void,
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    // 권한 확인
    guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
      completion(.failure(NSError(
        domain: "TranscriptionService",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "음성 인식 권한이 필요해요."]
      )))
      return
    }
    
    // Recognizer 생성
    guard let recognizer = SFSpeechRecognizer(locale: locale) else {
      completion(.failure(NSError(
        domain: "TranscriptionService",
        code: -2,
        userInfo: [NSLocalizedDescriptionKey: "음성 인식을 사용할 수 없어요."]
      )))
      return
    }
    
    guard recognizer.isAvailable else {
      completion(.failure(NSError(
        domain: "TranscriptionService",
        code: -3,
        userInfo: [NSLocalizedDescriptionKey: "음성 인식이 잠시 후에 가능해요."]
      )))
      return
    }
    
    print("🚀 Starting chunked transcription for: \(url.lastPathComponent)")
    
    // 1. 오디오 파일을 적합한 포맷으로 변환 (필요시)
    prepareAudioForRecognition(from: url) { [weak self] preparedURL, tempURL in
      guard let self = self else { return }
      
      // 2. 오디오 길이 확인 및 청크 생성
      self.splitAudioIntoChunks(url: preparedURL) { result in
        switch result {
        case .success(let chunks):
          print("📦 Created \(chunks.count) chunks")
          
          // 3. 청크를 병렬로 처리
          self.transcribeChunksInParallel(
            chunks: chunks,
            recognizer: recognizer,
            allowOnlineFallback: allowOnlineFallback,
            onProgress: onProgress
          ) { transcriptionResult in
            // 4. 임시 파일 정리
            for chunk in chunks {
              try? FileManager.default.removeItem(at: chunk.url)
            }
            if let tempURL = tempURL {
              try? FileManager.default.removeItem(at: tempURL)
            }
            
            // 5. 결과 반환
            switch transcriptionResult {
            case .success(let text):
              print("✅ Transcription completed: \(text.count) chars")
              completion(.success(text))
            case .failure(let error):
              print("❌ Transcription failed: \(error.localizedDescription)")
              completion(.failure(error))
            }
          }
          
        case .failure(let error):
          if let tempURL = tempURL {
            try? FileManager.default.removeItem(at: tempURL)
          }
          completion(.failure(error))
        }
      }
    }
  }
  
  private struct AudioChunk {
    let url: URL
    let index: Int
    let startTime: TimeInterval
    let duration: TimeInterval
  }
  
  private func splitAudioIntoChunks(
    url: URL,
    completion: @escaping (Result<[AudioChunk], Error>) -> Void
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      let asset = AVURLAsset(url: url)
      let duration = asset.duration.seconds
      
      guard duration > 0 else {
        completion(.failure(NSError(
          domain: "TranscriptionService",
          code: -4,
          userInfo: [NSLocalizedDescriptionKey: "오디오 길이를 확인할 수 없어요."]
        )))
        return
      }
      
      print("🎵 Audio duration: \(duration)s")
      
      // 청크 수 계산
      let numChunks = Int(ceil(duration / self.chunkDuration))
      var chunks: [AudioChunk] = []
      
      // 각 청크 생성
      for i in 0..<numChunks {
        let startTime = Double(i) * self.chunkDuration
        let chunkDuration = min(self.chunkDuration, duration - startTime)
        
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
          .appendingPathComponent("chunk_\(i)_\(UUID().uuidString)")
          .appendingPathExtension("m4a")
        
        let chunk = AudioChunk(
          url: tempURL,
          index: i,
          startTime: startTime,
          duration: chunkDuration
        )
        chunks.append(chunk)
      }
      
      // 청크 파일 생성
      let group = DispatchGroup()
      var errors: [Error] = []
      
      for chunk in chunks {
        group.enter()
        self.exportAudioChunk(
          asset: asset,
          startTime: chunk.startTime,
          duration: chunk.duration,
          outputURL: chunk.url
        ) { error in
          if let error = error {
            errors.append(error)
          }
          group.leave()
        }
      }
      
      group.notify(queue: .main) {
        if let firstError = errors.first {
          // 실패한 청크 정리
          for chunk in chunks {
            try? FileManager.default.removeItem(at: chunk.url)
          }
          completion(.failure(firstError))
        } else {
          completion(.success(chunks))
        }
      }
    }
  }
  
  private func exportAudioChunk(
    asset: AVAsset,
    startTime: TimeInterval,
    duration: TimeInterval,
    outputURL: URL,
    completion: @escaping (Error?) -> Void
  ) {
    guard let exportSession = AVAssetExportSession(
      asset: asset,
      presetName: AVAssetExportPresetAppleM4A
    ) else {
      completion(NSError(
        domain: "TranscriptionService",
        code: -5,
        userInfo: [NSLocalizedDescriptionKey: "Export session 생성 실패"]
      ))
      return
    }
    
    exportSession.outputURL = outputURL
    exportSession.outputFileType = .m4a
    exportSession.shouldOptimizeForNetworkUse = false
    
    let start = CMTime(seconds: startTime, preferredTimescale: 600)
    let duration = CMTime(seconds: duration, preferredTimescale: 600)
    let timeRange = CMTimeRange(start: start, duration: duration)
    exportSession.timeRange = timeRange
    
    exportSession.exportAsynchronously {
      if exportSession.status == .completed {
        completion(nil)
      } else {
        completion(exportSession.error ?? NSError(
          domain: "TranscriptionService",
          code: -6,
          userInfo: [NSLocalizedDescriptionKey: "청크 export 실패"]
        ))
      }
    }
  }
  
  private func transcribeChunksInParallel(
    chunks: [AudioChunk],
    recognizer: SFSpeechRecognizer,
    allowOnlineFallback: Bool,
    onProgress: @escaping (TranscriptionProgress) -> Void,
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    let totalChunks = chunks.count
    var completedChunks = 0
    var results: [Int: String] = [:] // index -> text
    var hasError = false
    var firstError: Error?
    
    let queue = DispatchQueue(label: "com.meetnote.transcription", attributes: .concurrent)
    let semaphore = DispatchSemaphore(value: maxConcurrentTasks)
    let group = DispatchGroup()
    
    // 초기 진행률
    onProgress(TranscriptionProgress(
      totalChunks: totalChunks,
      completedChunks: 0,
      currentChunk: 0
    ))
    
    for chunk in chunks {
      guard !hasError else { break }
      
      group.enter()
      queue.async { [weak self] in
        guard let self = self else {
          group.leave()
          return
        }
        
        semaphore.wait() // 동시 실행 제한
        
        print("🔄 Processing chunk \(chunk.index + 1)/\(totalChunks)")
        
        self.transcribeChunk(
          url: chunk.url,
          recognizer: recognizer,
          allowOnlineFallback: allowOnlineFallback
        ) { result in
          defer {
            semaphore.signal()
            group.leave()
          }
          
          switch result {
          case .success(let text):
            queue.sync(flags: .barrier) {
              guard !hasError else { return }
              
              results[chunk.index] = text
              completedChunks += 1
              
              print("✓ Chunk \(chunk.index + 1) done: \(text.prefix(50))...")
              
              // 진행률 업데이트
              DispatchQueue.main.async {
                onProgress(TranscriptionProgress(
                  totalChunks: totalChunks,
                  completedChunks: completedChunks,
                  currentChunk: chunk.index + 1
                ))
              }
            }
            
          case .failure(let error):
            queue.sync(flags: .barrier) {
              if !hasError {
                hasError = true
                firstError = error
              }
            }
          }
        }
      }
    }
    
    group.notify(queue: .main) {
      if let error = firstError {
        completion(.failure(error))
      } else {
        // 결과를 순서대로 병합
        let sortedTexts = (0..<totalChunks).compactMap { results[$0] }
        let finalText = sortedTexts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        
        if finalText.isEmpty {
          completion(.failure(NSError(
            domain: "TranscriptionService",
            code: -7,
            userInfo: [NSLocalizedDescriptionKey: "텍스트 변환 결과가 비어 있어요."]
          )))
        } else {
          completion(.success(finalText))
        }
      }
    }
  }
  
  private func transcribeChunk(
    url: URL,
    recognizer: SFSpeechRecognizer,
    allowOnlineFallback: Bool,
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    let request = SFSpeechURLRecognitionRequest(url: url)
    request.shouldReportPartialResults = false
    request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
    
    var task: SFSpeechRecognitionTask?
    task = recognizer.recognitionTask(with: request) { transcription, error in
      if let error = error {
        // On-device 실패시 online 재시도
        if request.requiresOnDeviceRecognition && allowOnlineFallback {
          let retryRequest = SFSpeechURLRecognitionRequest(url: url)
          retryRequest.shouldReportPartialResults = false
          retryRequest.requiresOnDeviceRecognition = false
          
          _ = recognizer.recognitionTask(with: retryRequest) { retryTranscription, retryError in
            if let retryError = retryError {
              completion(.failure(retryError))
            } else if let retryTranscription = retryTranscription, retryTranscription.isFinal {
              let text = retryTranscription.bestTranscription.formattedString
                .trimmingCharacters(in: .whitespacesAndNewlines)
              completion(.success(text))
            }
          }
        } else {
          completion(.failure(error))
        }
        return
      }
      
      guard let transcription = transcription, transcription.isFinal else {
        return
      }
      
      let text = transcription.bestTranscription.formattedString
        .trimmingCharacters(in: .whitespacesAndNewlines)
      completion(.success(text))
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
    
    guard compatiblePresets.contains(preset),
          let exportSession = AVAssetExportSession(asset: asset, presetName: preset) else {
      completion(url, nil)
      return
    }
    
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("m4a")
    
    exportSession.outputURL = tempURL
    exportSession.outputFileType = .m4a
    exportSession.shouldOptimizeForNetworkUse = false
    
    exportSession.exportAsynchronously {
      guard exportSession.status == .completed else {
        try? FileManager.default.removeItem(at: tempURL)
        completion(url, nil)
        return
      }
      completion(tempURL, tempURL)
    }
  }
  
  func cancelAll() {
    activeTasks.forEach { $0.cancel() }
    activeTasks.removeAll()
    activeRecognizers.removeAll()
  }
}
