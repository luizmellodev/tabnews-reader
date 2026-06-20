//
//  TextToSpeechManager.swift
//  newtabnews
//
//  Created by Luiz Mello on 19/11/25.
//

import Foundation
import AVFoundation
import Combine

class TextToSpeechManager: NSObject, ObservableObject {
    static let shared = TextToSpeechManager()
    
    private let synthesizer = AVSpeechSynthesizer()
    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var currentRate: Float = 1.0
    
    private var isRestarting = false
    private var audioSessionConfigured = false
    
    private override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        guard !audioSessionConfigured else { return }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
            audioSessionConfigured = true
        } catch {
            print("❌ [TTS] Erro ao configurar áudio: \(error)")
        }
    }
    
    private func avSpeechRate(from userSpeed: Float) -> Float {
        let normalRate = AVSpeechUtteranceDefaultSpeechRate
        let mappedRate = normalRate * userSpeed
        return min(max(mappedRate, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
    }
    
    func speak(text: String, title: String? = nil) {
        currentText = text
        currentTitle = title
        
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(true, options: [])
        } catch {
            print("❌ [TTS] Erro ao ativar áudio: \(error)")
        }
        
        let cleanText = cleanMarkdown(text)
        
        var fullText = cleanText
        if let title = title {
            fullText = "\(title). \(cleanText)"
        }
        
        guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let utterance = AVSpeechUtterance(string: fullText)
        utterance.voice = AVSpeechSynthesisVoice(language: "pt-BR")
        utterance.rate = avSpeechRate(from: currentRate)
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        isPlaying = true
        isPaused = false
        
        synthesizer.speak(utterance)
    }
    
    func pause() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.pauseSpeaking(at: .word)
        isPaused = true
        isPlaying = false
    }
    
    func resume() {
        guard synthesizer.isPaused else { return }
        synthesizer.continueSpeaking()
        isPaused = false
        isPlaying = true
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        isPaused = false
    }
    
    func togglePlayPause(text: String, title: String? = nil) {
        if isPlaying {
            pause()
        } else if isPaused {
            resume()
        } else {
            speak(text: text, title: title)
        }
    }
    
    private var currentText: String?
    private var currentTitle: String?
    
    // Remove markdown e deixa só o texto limpo
    private func cleanMarkdown(_ text: String) -> String {
        var cleaned = text
        
        cleaned = cleaned.replacingOccurrences(
            of: #"!\[([^\]]*)\]\(([^\)]+)\)"#,
            with: "",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: #"\[([^\]]+)\]\(([^\)]+)\)"#,
            with: "$1",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: #"https?://[^\s<>]+"#,
            with: "",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: #"\*\*([^*]+)\*\*"#,
            with: "$1",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: #"(?<!\*)\*([^*]+)\*(?!\*)"#,
            with: "$1",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: #"(?m)^#{1,6}\s+"#,
            with: "",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: #"(?m)^---+\s*$"#,
            with: "",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: #"(?m)^-\s+"#,
            with: "",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: #"`([^`]+)`"#,
            with: "$1",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: #"<!--[\s\S]*?-->"#,
            with: "",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: #"[ \t]{2,}"#,
            with: " ",
            options: .regularExpression
        )
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func setSpeed(_ speed: Float) {
        let newRate = speed
        
        if newRate != currentRate {
            let wasPlaying = isPlaying
            let wasPaused = isPaused
            
            currentRate = newRate
            
            if (wasPlaying || wasPaused) && currentText != nil {
                isRestarting = true
                synthesizer.stopSpeaking(at: .immediate)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let text = self.currentText {
                        self.speak(text: text, title: self.currentTitle)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.isRestarting = false
                        }
                    } else {
                        self.isRestarting = false
                    }
                }
            }
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension TextToSpeechManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPlaying = true
            self.isPaused = false
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            if !self.isRestarting {
                self.isPlaying = false
                self.isPaused = false
                self.currentText = nil
                self.currentTitle = nil
            }
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            if !self.isRestarting {
                self.isPlaying = false
                self.isPaused = false
            }
        }
    }
}

