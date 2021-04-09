import XCTest
@testable import TestingHost

class RoomTests: BaseTestCase {
    func testLastMessage() throws {
        // given the sample data set
        try dataController.createSampleData()
        
        let room = dataController.room(id: "!test0:example.org")!
        XCTAssertEqual(room.lastMessage?.body, "Hello Room 0 from User 9")
        
        // when adding a new message
        let message = dataController.createMessage(id: "new_message")
        message.body = "Hello, World!"
        message.date = Date()
        message.sender = (room.members as? Set<User>)?.first
        message.room = room
        dataController.save()
        
        // then the last message should return this new message
        XCTAssertEqual(room.lastMessage?.body, "Hello, World!")
        
        // when redacting the last message
        let redaction = Redaction(context: dataController.viewContext)
        redaction.id = "redact_hello"
        redaction.date = Date()
        redaction.message = message
        redaction.sender = (room.members as? Set<User>)?.first
        
        // then the last message should revert back to the sample data set
        XCTAssertEqual(room.lastMessage?.body, "Hello Room 0 from User 9")
    }
    
    func testLastMessageLoadingOldMessages() throws {
        // given the sample data set
        try dataController.createSampleData()
        
        let room = dataController.room(id: "!test0:example.org")!
        XCTAssertEqual(room.lastMessage?.body, "Hello Room 0 from User 9")
        
        // when adding an older message sent one hour ago
        let oldMessage = dataController.createMessage(id: "old_message")
        oldMessage.body = "Can you see this?"
        oldMessage.date = Date(timeIntervalSinceNow: -60 * 60)
        oldMessage.sender = (room.members as? Set<User>)?.first
        oldMessage.room = room
        dataController.save()
        
        // then the last message should not have changed
        XCTAssertEqual(room.lastMessage?.body, "Hello Room 0 from User 9")
    }
    
    func testRedactingLastMessage() throws {
        // given the sample data set
        try dataController.createSampleData()
        
        let room = dataController.room(id: "!test0:example.org")!
        XCTAssertEqual(room.lastMessage?.body, "Hello Room 0 from User 9")
        
        // when redacting the last message
        let redaction = Redaction(context: dataController.viewContext)
        redaction.id = "redact_hello"
        redaction.date = Date()
        redaction.message = room.lastMessage
        redaction.sender = (room.members as? Set<User>)?.first
        
        // then the redacted message shouldn't be returned as the last message
        XCTAssertEqual(room.lastMessage?.body, "Hello Room 0 from User 8")
    }
    
    func testDeletingRoomCascadeDeletesRoomData() throws {
        // given the sample data set
        try dataController.createSampleData()
        
        // when deleting the first room in the set
        let firstRoom = dataController.room(id: "!test0:example.org")!
        dataController.delete(firstRoom)
        dataController.save()
        
        // then the room along with all of it's members, messages, reactions, edits and redactions should no longer exist
        XCTAssertEqual(dataController.count(for: Room.fetchRequest()), 4, "There should be 4 rooms in the store.")
        XCTAssertEqual(dataController.count(for: User.fetchRequest()), 40, "There should be 40 users for the remaining rooms.")
        XCTAssertEqual(dataController.count(for: Message.fetchRequest()), 800, "There should be 800 messages for the remaining rooms.")
        XCTAssertEqual(dataController.count(for: Reaction.fetchRequest()), 8, "There should be 8 reactions for the remaining rooms.")
        XCTAssertEqual(dataController.count(for: Edit.fetchRequest()), 4, "There should be 4 edits for the remaining rooms.")
        XCTAssertEqual(dataController.count(for: Redaction.fetchRequest()), 4, "There should be 4 redactions for the remaining rooms.")
    }
    
    func testDeleteAllMessages() {
        // given 2 rooms each with 1 user and 20 messages
        let roomA = Room(context: dataController.viewContext)
        let roomB = Room(context: dataController.viewContext)
        roomA.id = "!testA:example.org"
        roomB.id = "!testB:example.org"
        
        let userA = dataController.createUser(id: "@userA:example.org", in: roomA)
        let userB = dataController.createUser(id: "@userB:example.org", in: roomB)
        
        for i in 0..<20 {
            let messageA = dataController.createMessage(id: "mA\(i)")
            messageA.body = "Message \(i)"
            messageA.sender = userA
            messageA.room = roomA
            
            let messageB = dataController.createMessage(id: "mB\(i)")
            messageB.body = "Message B \(i)"
            messageB.sender = userB
            messageB.room = roomB
        }
        
        dataController.save()
        
        XCTAssertEqual(dataController.count(for: roomA.messagesRequest), 20, "There should be 20 messages in room A")
        XCTAssertEqual(dataController.count(for: roomB.messagesRequest), 20, "There should be 20 messages in room B")
        XCTAssertEqual(dataController.count(for: Message.fetchRequest()), 40, "There should be 40 messages in total")
        
        // when all the messages are deleted from the first room
        roomA.deleteAllMessages()
        dataController.save()
        
        // then the first room should have no messages and the second room shouldn't have changed
        XCTAssertEqual(dataController.count(for: roomA.messagesRequest), 0, "There should be no messages in room A")
        XCTAssertEqual(dataController.count(for: roomB.messagesRequest), 20, "There should be 20 messages in room B")
        XCTAssertEqual(dataController.count(for: Message.fetchRequest()), 20, "There should be 20 messages in total")
    }
}
