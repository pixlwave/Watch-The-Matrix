import Matrix
import CoreData

extension Message {
    /// The type of content that this message contains such as text, image etc.
    var type: MessageContent.MessageType {
        MessageContent.MessageType(rawValue: typeString ?? "") ?? .unknown
    }
    
    /// A request that will fetch any reactions that have been made to this message.
    private var reactionsRequest: NSFetchRequest<Reaction> {
        let request = Reaction.fetchRequest()
        request.predicate = NSPredicate(format: "message == %@", self)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Reaction.date, ascending: true)]
        return request
    }
    
    /// The newest edit made to this message, or nil if no edits have been made.
    var lastEdit: Edit? {
        let request = Edit.fetchRequest()
        request.predicate = NSPredicate(format: "message == %@", self)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Edit.date, ascending: false)]
        request.fetchLimit = 1
        
        return try? managedObjectContext?.fetch(request).first
    }
    
    var mediaAspectRadio: Double? {
        guard mediaWidth > 0 && mediaHeight > 0 else { return nil }
        return mediaWidth / mediaHeight
    }
    
    var isReply: Bool {
        repliesToEventID != nil
    }
    
    /// Returns all unique reactions for this message along with their count and
    /// whether or not they should be selected for a particular user ID.
    func aggregatedReactions(for userID: String) -> [AggregatedReaction] {
        let reactions = (try? managedObjectContext?.fetch(reactionsRequest)) ?? []

        // store reactions in a counted set and record which reactions the user sent
        let reactionSet = NSCountedSet()
        var userReactions = [String: String]()
        
        reactions.forEach {
            guard let key = $0.key else { return }
            reactionSet.add(key)
            
            if $0.sender?.id == userID {
                userReactions[key] = $0.id
            }
        }
        
        // create the array of aggregated reactions
        return reactionSet.map {
            let key = $0 as! String
            return AggregatedReaction(key: key, count: reactionSet.count(for: key), eventIDToRedact: userReactions[key])
        }
    }
    
    func hasReaction(_ key: String, from userID: String?) -> Bool {
        guard let userID else { return false }
        
        let request = Reaction.fetchRequest()
        request.predicate = NSCompoundPredicate(type: .and, subpredicates: [
            NSPredicate(format: "message == %@", self),
            NSPredicate(format: "key == %@", key),
            NSPredicate(format: "sender.id == %@", userID)
        ])
        
        return ((try? managedObjectContext?.count(for: request)) ?? 0) > 0
    }
    
    func formatAsReply() {
        guard isReply else { return }
        formatBodyAsReply()
        formatHTMLBodyAsReply()
    }
    
    private func formatBodyAsReply() {
        guard let body else { return }
        
        let components = body.components(separatedBy: .newlines)
        
        guard
            let separatingLine = components.firstIndex(of: ""),
            separatingLine > 0,                     // The quote should have at least 1 line
            separatingLine < components.count - 1   // The reply should have at least 1 line
        else { return }
        
        var quoteComponents = components[0..<separatingLine]
        
        var validQuote = true
        for (index, line) in quoteComponents.enumerated() {
            guard line.hasPrefix("> ") else { validQuote = false; break }
            let unquoted = line.dropFirst(2)
            
            if index == 0 {
                guard
                    let senderEndRange = unquoted.range(of: "> "),
                    let firstIndex = unquoted.indices.first
                else { validQuote = false; break }
                
                quoteComponents[index] = unquoted.replacingCharacters(in: firstIndex..<senderEndRange.upperBound, with: "")
            } else {
                quoteComponents[index] = String(unquoted)
            }
        }
        
        guard validQuote else { return }
        
        self.body = components[(separatingLine + 1)...].joined(separator: "\n")
        self.replyQuote = quoteComponents.joined(separator: "\n")
    }
    
    private func formatHTMLBodyAsReply() {
        guard
            let htmlBody = htmlBody,
            let lastTagRange = htmlBody.range(of: "</mx-reply>", options: .backwards),
            let lastIndex = htmlBody.indices.last,
            lastTagRange.upperBound < lastIndex
        else { return }
        
        self.htmlBody = String(htmlBody[lastTagRange.upperBound...])
    }
}
