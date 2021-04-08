import XCTest
@testable import TestingHost

class RoomTests: BaseTestCase {
    func testDeleteAllMessages() {
        // given two rooms each with 20 messages
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
