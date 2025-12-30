import Foundation
import Speech
import AVFoundation
import Combine

final class SpeechTranscriber: NSObject, ObservableObject {
    enum State: Equatable {
        case idle
        case recording
        case processing
        case error(String)
    }

    @Published var state: State = .idle
    @Published var transcript: String = ""

    var onFinalTranscription: ((String) -> Void)?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func startRecording() {
        requestAuthorizationIfNeeded { [weak self] authorized in
            guard let self else { return }
            guard authorized else {
                DispatchQueue.main.async {
                    self.state = .error("Speech permission denied. Please enable microphone and speech access.")
                }
                return
            }

            DispatchQueue.main.async {
                self.beginRecordingSession()
            }
        }
    }

    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        if state == .recording {
            state = .processing
        }
    }

    private func beginRecordingSession() {
        resetSession()
        transcript = ""
        state = .recording

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            state = .error("Audio session error: \(error.localizedDescription)")
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            state = .error("Unable to create recognition request.")
            return
        }

        recognitionRequest.shouldReportPartialResults = true

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            state = .error("Speech recognizer unavailable.")
            return
        }

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.state = .processing
                        self.finishRecognition()
                    }
                }
            }

            if let error {
                DispatchQueue.main.async {
                    self.state = .error(error.localizedDescription)
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.inputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            state = .error("No valid audio input available. Check microphone permissions or device input.")
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        do {
            try audioEngine.start()
        } catch {
            state = .error("Audio engine error: \(error.localizedDescription)")
        }
    }

    private func finishRecognition() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil

        let finalTranscript = transcript
        onFinalTranscription?(finalTranscript)
        state = .idle
    }

    private func resetSession() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    private func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()

        switch speechStatus {
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { status in
                switch status {
                case .authorized:
                    self.requestMicrophonePermission(completion: completion)
                default:
                    completion(false)
                }
            }
        case .authorized:
            requestMicrophonePermission(completion: completion)
        default:
            completion(false)
        }
    }

    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        if #available(iOS 17, *) {
            let micStatus = AVAudioApplication.shared.recordPermission
            switch micStatus {
            case .undetermined:
                AVAudioApplication.requestRecordPermission { granted in
                    completion(granted)
                }
            case .granted:
                completion(true)
            default:
                completion(false)
            }
        } else {
            let micStatus = AVAudioSession.sharedInstance().recordPermission
            switch micStatus {
            case .undetermined:
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    completion(granted)
                }
            case .granted:
                completion(true)
            default:
                completion(false)
            }
        }
    }
}
