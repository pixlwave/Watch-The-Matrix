import CoreData

extension DataController {
    /// Create example rooms, users and messages for development and testing purposes
    func createSampleData() throws {
        for i in 0..<5 {
            // create 5 rooms
            let room = Room(context: viewContext)
            room.id = "!test\(i):example.org"
            room.name = "Room \(i)"
            
            var users = [Member]()
            
            // add 10 users to each room
            for j in 0..<10 {
                let user = createMember(id: "@user\(j):example.org", in: room)
                user.displayName = "User \(j)"
                users.append(user)
            }
            
            // add 20 messages to each room sent one by one from each user
            for j in 0..<20 {
                for k in 0..<users.count {
                    let user = users[k]
                    let message = createMessage(id: "\(i)\(j)\(k)-\(room.id!)")
                    message.body = "Hello \(room.name ?? "Room") from \(user.displayName ?? user.id!)"
                    message.date = Date()
                    message.sender = user
                    message.room = room
                }
                
                // add reactions to the 10th and 20th messages
                if j == 9 || j == 19 {
                    let reaction = Reaction(context: viewContext)
                    reaction.id = "r\(i)\(j)-\(room.id!)"
                    reaction.key = "👍"
                    reaction.date = Date()
                    reaction.sender = users.first
                    reaction.message = room.lastMessage
                }
                
                // redact the 18th message from the 10th user
                if j == 17 {
                    let redaction = Redaction(context: viewContext)
                    redaction.id = "redact\(i)\(j)-\(room.id!)"
                    redaction.date = Date()
                    redaction.sender = users.last
                    redaction.message = room.lastMessage
                }
                
                // edit the 19th message from the 10th user
                if j == 18 {
                    let edit = Edit(context: viewContext)
                    edit.id = "ed\(i)\(j)-\(room.id!)"
                    edit.body = "Hello, World!"
                    edit.date = Date()
                    edit.message = room.lastMessage
                }
            }
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
        
        print("Users: \(count(for: Member.fetchRequest()))")
        print((try? viewContext.fetch(Member.fetchRequest())) ?? [])
        
        print("Messages: \(count(for: Message.fetchRequest()))")
        print((try? viewContext.fetch(Message.fetchRequest())) ?? [])
        
        print("********** Store Data End **********")
    }
}
