//
//  OpenAIRealtimeResponseCancel.swift
//  AIProxy
//
//  Created by Assistant on 9/13/25.
//

import Foundation

/// Cancel an in-progress response from the model
/// https://platform.openai.com/docs/api-reference/realtime-client-events/response/cancel
public struct OpenAIRealtimeResponseCancel: Encodable {
    public let type = "response.cancel"
    
    public init() {}
}
