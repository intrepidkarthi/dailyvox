//
//  VoiceSearchManager.swift
//  solyn
//
//  Handles voice-to-text for search functionality.
//  Uses Apple's Speech framework for on-device recognition.
//

#if os(iOS)
import Foundation
import Speech
import AVFoundation

/// Manages voice search using Apple's Speech framework.
/// All recognition is performed on-device when possible.
final class VoiceSearchManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var transcribedText: String = ""
    @Published var isListening: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public Methods
    
    /// Start listening for voice input
    func startListening() {
        // Reset state
        transcribedText = ""
        errorMessage = nil
        
        // Check authorization
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.beginRecording()
                case .denied, .restricted:
                    self?.errorMessage = "Speech recognition not authorized"
                case .notDetermined:
                    self?.errorMessage = "Speech recognition not available"
                @unknown default:
                    self?.errorMessage = "Unknown authorization status"
                }
            }
        }
    }
    
    /// Stop listening and finalize transcription
    func stopListening() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }
    
    // MARK: - Private Methods
    
    private func beginRecording() {
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Failed to configure audio session"
            return
        }
        
        // Create audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            errorMessage = "Failed to create audio engine"
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Failed to create recognition request"
            return
        }
        
        // Configure for real-time results
        recognitionRequest.shouldReportPartialResults = true
        
        // Prefer on-device recognition for privacy
        if speechRecognizer?.supportsOnDeviceRecognition == true {
            recognitionRequest.requiresOnDeviceRecognition = true
        }
        
        // Start recognition task
        guard let speechRecognizer = speechRecognizer else {
            errorMessage = "Speech recognizer not available"
            return
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self?.transcribedText = result.bestTranscription.formattedString
                    
                    // Auto-stop after final result or pause
                    if result.isFinal {
                        self?.stopListening()
                    }
                }
                
                if let error = error {
                    // Ignore cancellation errors
                    let nsError = error as NSError
                    if nsError.domain != "kAFAssistantErrorDomain" || nsError.code != 216 {
                        self?.errorMessage = "Recognition error: \(error.localizedDescription)"
                    }
                    self?.stopListening()
                }
            }
        }
        
        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
            
            // Auto-stop after 5 seconds of listening
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                if self?.isListening == true {
                    self?.stopListening()
                    HapticManager.shared.recordingStopped()
                }
            }
        } catch {
            errorMessage = "Failed to start audio engine"
            stopListening()
        }
    }
}
#endif
