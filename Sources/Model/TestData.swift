import CoreData

extension DataController {
    /// Prints debug data about the store's contents to the console.
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
