import Matrix
import CoreData

extension Message {
    /// The type of content that this message contains such as text, image etc.
    var type: MessageContent.MessageType {
        MessageContent.MessageType(rawValue: typeString ?? "") ?? .unknown
    }
    
    /// A request that will fetch any reactions that have been made to this message.
    private var reactionsRequest: NSFetchRequest<Reaction> {
        let request: NSFetchRequest<Reaction> = Reaction.fetchRequest()
        request.predicate = NSPredicate(format: "message == %@", self)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Reaction.date, ascending: true)]
        return request
    }
    
    /// A an array of tuples of unique reactions and their count for this message.
    var reactionsViewModel: [(key: String, count: Int)] {
        // get all unique reaction keys
        let reactions = (try? managedObjectContext?.fetch(reactionsRequest)) ?? []
        let keys = NSOrderedSet(array: reactions.compactMap { $0.key })
        
        // make an array of tuples containing each key and it's count
        return keys.compactMap {
            let key = $0 as! String
            let count = reactions.filter { $0.key == key }.count
            
            return (key: key, count: count)
        }
    }
    
    /// The newest edit made to this message, or nil if no edits have been made.
    var lastEdit: Edit? {
        let request: NSFetchRequest<Edit> = Edit.fetchRequest()
        request.predicate = NSPredicate(format: "message == %@", self)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Edit.date, ascending: false)]
        request.fetchLimit = 1
        
        return try? managedObjectContext?.fetch(request).first
    }
    
    /// A fetch request for all redactions made to this message.
    private var redactionsRequest: NSFetchRequest<Redaction> {
        let request: NSFetchRequest<Redaction> = Redaction.fetchRequest()
        request.predicate = NSPredicate(format: "message == %@", self)
        return request
    }
    
    /// A boolean that indicates whether this message has been redacted or not.
    var isRedacted: Bool {
        // check if there is at least 1 redaction
        return (try? managedObjectContext?.count(for: redactionsRequest)) ?? 0 > 0
    }
    
    var mediaAspectRadio: Double? {
        guard mediaWidth > 0 && mediaHeight > 0 else { return nil }
        return mediaWidth / mediaHeight
    }
    
    var isReply: Bool {
        repliesToEventID != nil
    }
    
    func formatAsReply() {
        guard isReply, let body = body else { return }
        
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
}
