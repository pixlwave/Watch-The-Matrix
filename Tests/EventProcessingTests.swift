import XCTest
@testable import Watch_The_Matrix_WatchKit_Extension
import Matrix

class EventProcessingTests: BaseTestCase {
    func testProcessNewJoinedRoom() throws {
        // given a joined room response with one member and one message
        let joinedRoom = try loadJSON(named: "NewJoinedRoom", as: JoinedRoom.self)
        
        let room = Room(context: dataController.viewContext)
        room.id = "!room:example.org"
        
        // when processing the events from this response
        joinedRoom.state?.events?.forEach { dataController.processStateEvent($0, in: room) }
        dataController.process(events: joinedRoom.timeline?.events ?? [], in: room, includeState: true)
        
        dataController.save()
        
        // then there should be one room, one member and one message created
        XCTAssertEqual(dataController.count(for: Room.fetchRequest()), 1, "There should be 1 room.")
        XCTAssertEqual(dataController.count(for: Member.fetchRequest()), 1, "There should be 1 member.")
        XCTAssertEqual(dataController.count(for: Message.fetchRequest()), 1, "There should be 1 message.")
    }
    
    
    func testProcessNewMessageForExistingRoom() throws {
        // given a room with one message and one member
        try testProcessNewJoinedRoom()
        
        let joinedRoom = try loadJSON(named: "SyncMessageJoinedRoom", as: JoinedRoom.self)
        
        // when processing a sync response with one new message for the room from the same member
        let room = dataController.room(id: "!room:example.org")!
        
        joinedRoom.state?.events?.forEach { dataController.processStateEvent($0, in: room) }
        dataController.process(events: joinedRoom.timeline?.events ?? [], in: room, includeState: true)
        
        dataController.save()
        
        // then the only change should be one additional message in the data store
        XCTAssertEqual(dataController.count(for: Room.fetchRequest()), 1, "There should be 1 room.")
        XCTAssertEqual(dataController.count(for: Member.fetchRequest()), 1, "There should be 1 member.")
        XCTAssertEqual(dataController.count(for: Message.fetchRequest()), 2, "There should be 2 messages.")
        
        let fetchedRoom = dataController.room(id: "!room:example.org")!
        let fetchedMember = dataController.member(id: "@test:example.org", in: fetchedRoom)!
        
        XCTAssertEqual(dataController.count(for: fetchedRoom.messagesRequest), 2, "There should be 2 messages in the room.")
        XCTAssertEqual(fetchedRoom.members?.count, 1)
        XCTAssertEqual(fetchedRoom.name, "Test Room", "The room's name should be \"Test Room\" and shouldn't have changed.")
        XCTAssertEqual(fetchedMember.displayName, "Test User", "The member's name should be \"Test User\" and shouldn't have changed.")
    }
    
}
