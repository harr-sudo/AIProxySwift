//
//  OpenAIRealtimeConversationItemTruncate.swift
//  AIProxy
//
//  Created by Assistant on 9/13/25.
//

import Foundation

/// Truncate a conversation item at a specified point
/// https://platform.openai.com/docs/api-reference/realtime-client-events/conversation/item/truncate
public struct OpenAIRealtimeConversationItemTruncate: Encodable {
    public let type = "conversation.item.truncate"
    public let itemId: String
    public let contentIndex: Int
    public let audioEndMs: Int
    
    private enum CodingKeys: String, CodingKey {
        case type
        case itemId = "item_id"
        case contentIndex = "content_index"
        case audioEndMs = "audio_end_ms"
    }
    
    /// Initialize a conversation item truncate request
    /// - Parameters:
    ///   - itemId: The ID of the conversation item to truncate
    ///   - contentIndex: The index of the content part to truncate
    ///   - audioEndMs: The timestamp in milliseconds where the audio should be truncated
    public init(itemId: String, contentIndex: Int, audioEndMs: Int) {
        self.itemId = itemId
        self.contentIndex = contentIndex
        self.audioEndMs = audioEndMs
    }
}
