import CoreData

extension MatrixController {
    /// An instance of MatrixController with sample data ready for previews.
    static var preview: MatrixController {
        let matrix = MatrixController(inMemory: true)
        
        do {
            try matrix.dataController.createSampleData()
        } catch {
            fatalError("Error creating preview data: \(error)")
        }
        
        return matrix
    }
}


extension DataController {
    /// Create example rooms, members and messages for development and testing purposes
    func createSampleData() throws {
        for i in 0..<5 {
            // create 5 rooms
            let room = Room(context: viewContext)
            room.id = "!test\(i):example.org"
            room.name = "Room \(i)"
            room.unreadCount = i > 2 ? 1 : 0
            
            var members = [Member]()
            
            // add 10 members to each room
            for j in 0..<10 {
                let member = createMember(id: "@user\(j):example.org", in: room)
                member.displayName = "User \(j)"
                members.append(member)
            }
            
            // add 20 messages to each room sent one by one from each member
            for j in 0..<20 {
                for k in 0..<members.count {
                    let sender = members[k]
                    let message = createMessage(id: "\(i)\(j)\(k)-\(room.id!)")
                    message.body = "Hello \(room.name ?? "Room") from \(sender.displayName ?? sender.id!)"
                    message.date = Date()
                    message.sender = sender
                    message.room = room
                }
                
                // add reactions to the 10th and 20th messages
                if j == 9 || j == 19 {
                    let reaction = Reaction(context: viewContext)
                    reaction.id = "r\(i)\(j)-\(room.id!)"
                    reaction.key = "👍"
                    reaction.date = Date()
                    reaction.sender = members.first
                    reaction.message = room.lastMessage
                }
                
                // redact the 18th message from the 10th member
                if j == 17 {
                    room.lastMessage?.isRedacted = true
                }
                
                // edit the 19th message from the 10th member
                if j == 18 {
                    let edit = Edit(context: viewContext)
                    edit.id = "ed\(i)\(j)-\(room.id!)"
                    edit.body = "Hello, World!"
                    edit.date = Date()
                    edit.message = room.lastMessage
                }
            }
            
            // add 1 pending redaction to the room
            let redaction = Redaction(context: viewContext)
            redaction.id = "pending-redaction\(i)\(0)-\(room.id!)"
            redaction.eventID = "unsynced-message\(i)\(000)-\(room.id!)"
            redaction.date = Date()
            redaction.sender = members.last
            redaction.room = room
            
            // update the room's last message date for sorting
            room.updateCachedProperties()
        }
        
        let state = syncState()
        state.nextBatch = "next_batch"
        
        try viewContext.save()
    }
    
    /// Prints debug data about the store's contents to the console.
    func printStoreData() {
        print("********** Store Data Start **********")
        
        print("Room: \(count(for: Room.fetchRequest()))")
        print((try? viewContext.fetch(Room.fetchRequest())) ?? [])
        
        print("Members: \(count(for: Member.fetchRequest()))")
        print((try? viewContext.fetch(Member.fetchRequest())) ?? [])
        
        print("Messages: \(count(for: Message.fetchRequest()))")
        print((try? viewContext.fetch(Message.fetchRequest())) ?? [])
        
        print("********** Store Data End **********")
    }
}
