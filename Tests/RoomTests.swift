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
        message.sender = (room.members as? Set<Member>)?.first
        message.room = room
        dataController.save()
        
        // then the last message should return this new message
        XCTAssertEqual(room.lastMessage?.body, "Hello, World!")
        
        // when redacting the last message
        let redaction = Redaction(context: dataController.viewContext)
        redaction.id = "redact_hello"
        redaction.date = Date()
        redaction.message = message
        redaction.sender = (room.members as? Set<Member>)?.first
        
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
        oldMessage.sender = (room.members as? Set<Member>)?.first
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
        redaction.sender = (room.members as? Set<Member>)?.first
        
        // then the redacted message shouldn't be returned as the last message
        XCTAssertEqual(room.lastMessage?.body, "Hello Room 0 from User 8")
    }
    
    func testMemberCount() throws {
        // given the sample data set
        try dataController.createSampleData()
        
        let firstRoom = dataController.room(id: "!test0:example.org")!
        XCTAssertEqual(firstRoom.memberCount, 10, "There should be 10 users in the first room")
        
        // when adding one new member to the first room and another to the last room
        _ = dataController.createMember(id: "@userA:example.org", in: firstRoom)
        
        let secondRoom = dataController.room(id: "!test1:example.org")!
        _ = dataController.createMember(id: "@userB:example.org", in: secondRoom)
        
        // then there should be an additional member counted in the room
        XCTAssertEqual(firstRoom.memberCount, 11, "There should be 11 users in the first room.")
    }
    
    func testGenerateRoomName() {
        // given an un-named room with 4 members
        let room = Room(context: dataController.viewContext)
        room.id = "!test:example.org"
        
        let userA = dataController.createMember(id: "@userA:example.org", in: room)
        userA.displayName = "Apple"
        
        let userB = dataController.createMember(id: "@userB:example.org", in: room)
        userB.displayName = "Banana"
        
        let userC = dataController.createMember(id: "@userC:example.org", in: room)
        userC.displayName = "Coconut"
        
        let userD = dataController.createMember(id: "@userD:example.org", in: room)
        userD.displayName = "Durian"
        
        dataController.save()
        
        // when the current user is the last of these users
        let userID = userD.id
        
        // then the room name should contain the names of the first 3 users
        // the exact format of this will change with system's region and language
        XCTAssertEqual(room.generateName(for: userID), "Apple, Banana, and Coconut")
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
        XCTAssertEqual(dataController.count(for: Member.fetchRequest()), 40, "There should be 40 users for the remaining rooms.")
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
        
        let userA = dataController.createMember(id: "@userA:example.org", in: roomA)
        let userB = dataController.createMember(id: "@userB:example.org", in: roomB)
        
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
