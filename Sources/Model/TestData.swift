import CoreData

extension DataController {
    func addTestData1() {
        let room = Room(context: viewContext)
        room.id = "12345"
        room.name = "Test Room"
        
        let user = User(context: viewContext)
        user.id = "@test:example.org"
        user.displayName = "Test User"
        
        let message = Message(context: viewContext)
        message.id = "m12345"
        message.body = "HELLO, WORLD!"
        message.date = Date()
        
        room.members = [user]
        message.room = room
        message.sender = user
        
        save()
    }
    
    func addTestData2() {
        let room = Room(context: viewContext)
        room.id = "12345"
        
        let user = User(context: viewContext)
        user.id = "@test:example.org"
        
        let message = Message(context: viewContext)
        message.id = "m23456"
        message.body = "A message that arrived later"
        message.date = Date()
        message.room = room
        message.sender = user
        
        save()
    }
    
    func printStoreData() {
        print("********** Store Data Start **********")
        
        print("Room: \(count(for: Room.fetchRequest()))")
        print((try? viewContext.fetch(Room.fetchRequest())) ?? [])
        
        print("Users: \(count(for: User.fetchRequest()))")
        print((try? viewContext.fetch(User.fetchRequest())) ?? [])
        
        print("Messages: \(count(for: Message.fetchRequest()))")
        print((try? viewContext.fetch(Message.fetchRequest())) ?? [])
        
        print("********** Store Data End **********")
    }
}
