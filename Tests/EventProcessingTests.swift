import XCTest
@testable import TestingHost
import Matrix

class EventProcessingTests: BaseTestCase {
    func testProcessNewJoinedRoom() {
        // given a joined room response with one user and one message
        let joinedRoom = loadJoinedRoomJSON(named: "NewJoinedRoom")!
        
        let room = Room(context: dataController.viewContext)
        room.id = "!room:example.org"
        
        // when processing the events from this response
        joinedRoom.state.events.forEach { dataController.processStateEvent($0, in: room) }
        dataController.process(events: joinedRoom.timeline.events, in: room, includeState: true)
        
        dataController.save()
        
        // then there should be one room, one user and one message created
        XCTAssertEqual(dataController.count(for: Room.fetchRequest()), 1, "There should be 1 room.")
        XCTAssertEqual(dataController.count(for: User.fetchRequest()), 1, "There should be 1 user.")
        XCTAssertEqual(dataController.count(for: Message.fetchRequest()), 1, "There should be 1 message.")
    }
    
    
    func testProcessNewMessageForExistingRoom() {
        // given a room with one message and one user
        testProcessNewJoinedRoom()
        
        let joinedRoom = loadJoinedRoomJSON(named: "SyncMessageJoinedRoom")!
        
        // when processing a sync response with one new message for the room from the same user
        let room = dataController.room(id: "!room:example.org")!
        
        joinedRoom.state.events.forEach { dataController.processStateEvent($0, in: room) }
        dataController.process(events: joinedRoom.timeline.events, in: room, includeState: true)
        
        dataController.save()
        
        // then the only change should be one additional message in the data store
        XCTAssertEqual(dataController.count(for: Room.fetchRequest()), 1, "There should be 1 room.")
        XCTAssertEqual(dataController.count(for: User.fetchRequest()), 1, "There should be 1 user.")
        XCTAssertEqual(dataController.count(for: Message.fetchRequest()), 2, "There should be 2 messages.")
        
        let fetchedRoom = dataController.room(id: "!room:example.org")!
        let fetchedUser = dataController.user(id: "@test:example.org", in: fetchedRoom)!
        
        XCTAssertEqual(dataController.count(for: fetchedRoom.messagesRequest), 2, "There should be 2 messages in the room.")
        XCTAssertEqual(fetchedRoom.members?.count, 1)
        XCTAssertEqual(fetchedRoom.name, "Test Room", "The room's name should be \"Test Room\" and shouldn't have changed.")
        XCTAssertEqual(fetchedUser.displayName, "Test User", "The user's name should be \"Test User\" and shouldn't have changed.")
    }
    
}
