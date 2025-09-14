//
//  AITranscriptStateMachine.swift
//  mad4
//
//  Created by Assistant on 9/13/25.
//  Phase 2 — AI Transcript State Machine Implementation
//

import Foundation

/// State machine for managing AI transcript updates with revision safety and Arabic support
public final class AITranscriptStateMachine {
    
    // MARK: - State Properties
    private var workingBuffer: String = ""
    private var currentRevision: Int = 0
    private var lastRenderedRevision: Int = -1
    private var debounceTask: Task<Void, Never>?
    private var isFinalized: Bool = false
    private var messageId: UUID?
    
    // MARK: - Configuration
    private let debounceDelayNs: UInt64 = 125_000_000 // 125ms - Arabic-friendly
    private let minGraphemesForRender: Int = 3
    private let isDebugEnabled: Bool = true
    
    // MARK: - Callbacks
    private let onRenderIntermediate: (UUID, String, Int) -> Void
    private let onRenderFinal: (UUID, String, Int) -> Void
    private let onAnomalyDetected: (String) -> Void
    
    // MARK: - Initialization
    public init(
        onRenderIntermediate: @escaping (UUID, String, Int) -> Void,
        onRenderFinal: @escaping (UUID, String, Int) -> Void,
        onAnomalyDetected: @escaping (String) -> Void
    ) {
        self.onRenderIntermediate = onRenderIntermediate
        self.onRenderFinal = onRenderFinal
        self.onAnomalyDetected = onAnomalyDetected
    }
    
    // MARK: - Public Interface
    
    /// Handle transcript delta with snapshot semantics and revision safety
    public func handleTranscriptDelta(_ delta: String, eventIndex: Int? = nil) {
        let revision = eventIndex ?? (currentRevision + 1)
        
        debugLog("📝 AI Delta: '\(delta.prefix(30))...' (rev: \(revision), last: \(lastRenderedRevision))")
        
        // Revision safety - ignore older revisions
        guard revision >= lastRenderedRevision else {
            debugLog("⚠️ Ignoring old revision \(revision) (last: \(lastRenderedRevision))")
            return
        }
        
        // Initialize message ID if needed
        if messageId == nil {
            messageId = UUID()
            debugLog("🆔 Created new AI message ID: \(messageId!)")
        }
        
        // Snapshot semantics - replace entire buffer with latest delta
        let previousBuffer = workingBuffer
        workingBuffer = delta
        currentRevision = revision
        isFinalized = false
        
        // Log revisions for debugging
        logRevisionChange(from: previousBuffer, to: delta, revision: revision)
        
        // Schedule Arabic-friendly debounced render
        scheduleRender()
    }
    
    /// Handle final transcript - authoritative source
    public func handleTranscriptDone(_ finalText: String, eventIndex: Int? = nil) {
        let revision = eventIndex ?? (currentRevision + 1)
        
        debugLog("🏁 AI Final: '\(finalText.prefix(30))...' (rev: \(revision))")
        
        // Cancel any pending renders
        cancelDebounce()
        
        // Ensure we have a message ID
        if messageId == nil {
            messageId = UUID()
            debugLog("🆔 Created new AI message ID for final: \(messageId!)")
        }
        
        // Set final state
        workingBuffer = finalText
        currentRevision = revision
        isFinalized = true
        
        // Render immediately
        renderFinal()
    }
    
    /// Handle response.done as fallback finalization
    public func handleResponseDone(eventIndex: Int? = nil) {
        debugLog("🔚 Response done (finalized: \(isFinalized))")
        
        if !isFinalized {
            // Anomaly detected - log and finalize current state
            let anomaly = "response.done received without response.audio_transcript.done"
            onAnomalyDetected(anomaly)
            debugLog("⚠️ ANOMALY: \(anomaly)")
            
            // Finalize whatever we have
            finalizeCurrent()
        }
        
        // Clean up regardless
        cleanup()
    }
    
    /// Start a new AI response turn (preserves conversation but creates new message)
    public func startNewTurn() {
        debugLog("🆕 Starting new AI response turn")
        cancelDebounce()
        workingBuffer = ""
        currentRevision = 0
        lastRenderedRevision = -1
        isFinalized = false
        messageId = nil // This will force creation of a new message ID
    }
    
    /// Reset state for new conversation
    public func reset() {
        debugLog("🔄 Resetting AI transcript state machine")
        cancelDebounce()
        workingBuffer = ""
        currentRevision = 0
        lastRenderedRevision = -1
        isFinalized = false
        messageId = nil
    }
    
    // MARK: - Private Methods
    
    private func scheduleRender() {
        // Cancel any existing debounce
        debounceTask?.cancel()
        
        debounceTask = Task { [workingBuffer, currentRevision] in
            do {
                try await Task.sleep(nanoseconds: debounceDelayNs)
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                // Verify we still have the same content (not superseded)
                guard workingBuffer == self.workingBuffer && currentRevision == self.currentRevision else {
                    self.debugLog("⏭️ Skipping stale render (content changed)")
                    return
                }
                
                // Check if we should render this content
                if shouldRender(workingBuffer) {
                    renderIntermediate()
                } else {
                    debugLog("⏸️ Deferring render - waiting for more content: '\(workingBuffer.prefix(20))...'")
                }
                
            } catch {
                // Task was cancelled - this is normal
            }
        }
    }
    
    private func shouldRender(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Empty or whitespace-only text
        guard !trimmed.isEmpty else { return false }
        
        // Arabic-friendly content detection using grapheme clusters
        let graphemeCount = trimmed.count // Swift's count is grapheme-cluster aware
        
        // Render if we have enough graphemes
        if graphemeCount >= minGraphemesForRender {
            return true
        }
        
        // Render if we have word boundaries (works for Arabic and English)
        if trimmed.contains(" ") {
            return true
        }
        
        // Render if we have complete Arabic words (basic heuristic)
        if hasCompleteArabicWord(trimmed) {
            return true
        }
        
        // Render if text is getting long (fallback)
        if graphemeCount >= 8 {
            return true
        }
        
        return false
    }
    
    private func hasCompleteArabicWord(_ text: String) -> Bool {
        // Arabic Unicode range: U+0600–U+06FF
        let arabicRange = CharacterSet(charactersIn: "\u{0600}"..."\u{06FF}")
        
        // Check if text contains Arabic characters
        let hasArabic = text.unicodeScalars.contains { arabicRange.contains($0) }
        
        if hasArabic {
            // For Arabic, consider 2+ characters as a potential word
            // Arabic is written without spaces between some word parts
            return text.count >= 2
        }
        
        // For non-Arabic text, use basic word detection
        return text.range(of: "\\b\\w{2,}\\b", options: .regularExpression) != nil
    }
    
    private func renderIntermediate() {
        guard let id = messageId else { return }
        
        lastRenderedRevision = currentRevision
        onRenderIntermediate(id, workingBuffer, currentRevision)
        
        debugLog("📤 Rendered intermediate: '\(workingBuffer.prefix(30))...' (rev: \(currentRevision))")
    }
    
    private func renderFinal() {
        guard let id = messageId else { return }
        
        lastRenderedRevision = currentRevision
        onRenderFinal(id, workingBuffer, currentRevision)
        
        debugLog("🎯 Rendered final: '\(workingBuffer.prefix(30))...' (rev: \(currentRevision))")
    }
    
    private func finalizeCurrent() {
        guard !workingBuffer.isEmpty, messageId != nil else { return }
        
        isFinalized = true
        renderFinal()
        
        debugLog("🔧 Force-finalized current buffer: '\(workingBuffer.prefix(30))...'")
    }
    
    private func cancelDebounce() {
        debounceTask?.cancel()
        debounceTask = nil
    }
    
    private func cleanup() {
        cancelDebounce()
        // Keep the final state but mark as complete
        debugLog("🧹 Cleaned up AI transcript state machine")
    }
    
    private func logRevisionChange(from previous: String, to current: String, revision: Int) {
        guard isDebugEnabled && !previous.isEmpty && previous != current else { return }
        
        if current.count < previous.count {
            debugLog("🔄 AI revised shorter (rev \(revision)): '\(previous.prefix(20))...' → '\(current.prefix(20))...'")
        } else if current.count > previous.count {
            debugLog("🔄 AI expanded (rev \(revision)): '\(previous.prefix(20))...' → '\(current.prefix(20))...'")
        } else {
            debugLog("🔄 AI changed (rev \(revision)): '\(previous.prefix(20))...' → '\(current.prefix(20))...'")
        }
    }
    
    private func debugLog(_ message: String) {
        guard isDebugEnabled else { return }
        print("[AITranscriptStateMachine] \(message)")
    }
}
