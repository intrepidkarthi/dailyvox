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
    /// The same resolver entry transcription uses (`onDeviceRecognizer`): the
    /// "Language you speak" choice, else the speaker's own language, only
    /// with an on-device model, and English stand-ins only for English
    /// speakers. Resolved when listening starts, so a new choice in Settings
    /// applies to the very next search. Not Locale.current: on a Hindi phone
    /// that is en_IN (the app is not localised in Hindi), which would turn
    /// spoken Hindi search terms into English words.
    private var speechRecognizer: SFSpeechRecognizer?
    
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
                    self?.errorMessage = String(localized: "Speech recognition not authorized",
                                                comment: "Journal voice search: error published for the search bar when the user denied speech recognition. About 40 characters.")
                case .notDetermined:
                    self?.errorMessage = String(localized: "Speech recognition not available",
                                                comment: "Journal voice search: error published for the search bar when speech recognition permission has not been decided. About 40 characters.")
                @unknown default:
                    self?.errorMessage = String(localized: "Unknown authorization status",
                                                comment: "Journal voice search: error published for the search bar when iOS reports a speech permission state the app does not know. About 40 characters.")
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

        // ON-DEVICE, ALWAYS — the same rule as entry transcription, and checked
        // before the microphone is opened rather than after.
        //
        // "Prefer on-device" meant a recogniser without on-device support sent
        // what you spoke into the search field to Apple. A search box is a diary
        // query; it leaks the same things the entries do.
        speechRecognizer = SpeechTranscriber.onDeviceRecognizer()
        guard speechRecognizer?.supportsOnDeviceRecognition == true else {
            errorMessage = String(localized: "Voice search needs an on-device speech model. Add your language under Settings > General > Keyboard > Dictation Languages — DailyVox will not send your voice to a server.",
                                  comment: "Journal voice search: error published for the search bar when this iPhone has no on-device model for the language. 'Settings > General > Keyboard > Dictation Languages' must match the iOS Settings path in the target language exactly. Keep the promise that DailyVox never sends the voice to a server.")
            return
        }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = String(localized: "Failed to configure audio session",
                                  comment: "Journal voice search: error published for the search bar when the microphone could not be set up. About 40 characters.")
            return
        }
        
        // Create audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            errorMessage = String(localized: "Failed to create audio engine",
                                  comment: "Journal voice search: error published for the search bar when the microphone could not be set up. About 40 characters.")
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = String(localized: "Failed to create recognition request",
                                  comment: "Journal voice search: error published for the search bar when the speech request could not be created. About 40 characters.")
            return
        }
        
        // Configure for real-time results
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionRequest.requiresOnDeviceRecognition = true
        
        // Start recognition task
        guard let speechRecognizer = speechRecognizer else {
            errorMessage = String(localized: "Speech recognizer not available",
                                  comment: "Journal voice search: error published for the search bar when no recognizer exists for the language. About 40 characters.")
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
                        self?.errorMessage = String(localized: "Recognition error: \(error.localizedDescription)",
                                                    comment: "Journal voice search: error published for the search bar when recognition failed. The placeholder is iOS's own error description, already in the user's language.")
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
            errorMessage = String(localized: "Failed to start audio engine",
                                  comment: "Journal voice search: error published for the search bar when the microphone could not start. About 40 characters.")
            stopListening()
        }
    }
}
#endif
