import Matrix
import Combine
import Observation
import HTMLEntities

/// A class that represents a transaction for outbound messages.
@Observable class MessageTransaction: Identifiable {
    /// The transaction ID used when sending the message.
    let id: String
    /// The content of the message.
    let content: MessageContent
    /// The ID of the room that the message is for.
    let roomID: String
    /// The original message without any reply formatting applied.
    let originalMessage: String
    
    /// A cancellable token for the send operation.
    var token: AnyCancellable?
    /// The event ID created by the server if the message was sent successfully.
    var eventID: String?
    /// An error that occurred when sending the message, otherwise nil.
    var error: MatrixError?
    
    var isDelivered: Bool {
        eventID != nil
    }
    
    init(id: String, message: String, asReplyTo messageToQuote: Message? = nil, roomID: String) {
        self.id = id
        self.roomID = roomID
        self.originalMessage = message
        
        var content: MessageContent?
        if let messageToQuote,
           let quoteID = messageToQuote.id,
           let quoteBody = messageToQuote.body,
           let quoteSender = messageToQuote.sender?.id {
            // create the plain text body
            var components = quoteBody.components(separatedBy: .newlines)
            components[0] = "<\(quoteSender)> \(components[0])"     // note: no need to check for empty array as that won't happen
            let body = components.map { "> \($0)" }.joined(separator: "\n").appending("\n\n\(message)")
            
            // create the html body
            let quoteHTMLBody = messageToQuote.htmlBody ?? quoteBody.htmlEscape()
            let htmlBody = "<mx-reply><blockquote><a href=\"https://matrix.to/#/\(roomID)/\(quoteID)\">In reply to</a> <a href=\"https://matrix.to/#/\(quoteSender)\">\(quoteSender)</a><br />\(quoteHTMLBody)</blockquote></mx-reply>\(message)"
            
            content = MessageContent(body: body, type: .text, htmlBody: htmlBody, relationship: Relationship(type: .reply, eventID: quoteID))
        }
        
        self.content = content ?? MessageContent(body: message, type: .text)
    }
}
