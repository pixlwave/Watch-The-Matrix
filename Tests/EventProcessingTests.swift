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
        dataController.process(events: joinedRoom.timeline?.events, in: room, paginating: .forwards)
        
        dataController.save()
        
        // then there should be one room, one member and one message created
        XCTAssertEqual(dataController.count(for: Room.fetchRequest()), 1, "There should be 1 room.")
        XCTAssertEqual(dataController.count(for: Member.fetchRequest()), 1, "There should be 1 member.")
        XCTAssertEqual(dataController.count(for: Message.fetchRequest()), 1, "There should be 1 message.")
        
        // and the room's last message should reflect the sync response
        XCTAssertEqual(room.lastMessage?.body, "Hello, World", "The room's last message body should match the sync response.")
        XCTAssertEqual(room.excerpt, "Hello, World", "The room's excerpt match the sync response.")
        XCTAssertNotNil(room.lastMessageDate, "The lastMessageDate property should have been set.")
        XCTAssertEqual(room.lastMessageDate, room.lastMessage?.date, "The lastMessageDate property should match the room's lastMessage.")
    }
    
    
    func testProcessNewMessageForExistingRoom() throws {
        // given a room with one message and one member
        try testProcessNewJoinedRoom()
        
        let room = dataController.room(id: "!room:example.org")!
        
        // when processing a sync response with one new message for the room from the same member
        let joinedRoom = try loadJSON(named: "SyncMessageJoinedRoom", as: JoinedRoom.self)
        joinedRoom.state?.events?.forEach { dataController.processStateEvent($0, in: room) }
        dataController.process(events: joinedRoom.timeline?.events, in: room, paginating: .forwards)
        
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
        
        // and the room's last message should reflect the sync response
        XCTAssertEqual(room.lastMessage?.body, "A message that arrived later", "The room's last message body should match the sync response.")
        XCTAssertEqual(room.excerpt, "A message that arrived later", "The room's excerpt should have been updated.")
        XCTAssertNotNil(room.lastMessageDate, "The lastMessageDate property should have been set.")
        XCTAssertEqual(room.lastMessageDate, room.lastMessage?.date, "The lastMessageDate property should match the room's lastMessage.")
    }
    
    func testNewJoinedRoomWithReaction() throws {
        // given a joined room response with a single reaction event
        let dict = try loadJSON(named: "SyncNewRoomWithReaction", as: [String: JoinedRoom].self)
        let roomID = dict.keys.first!
        let joinedRoom = dict[roomID]!
        
        let room = Room(context: dataController.viewContext)
        room.id = roomID
        
        // when processing the events from this response
        joinedRoom.state?.events?.forEach { dataController.processStateEvent($0, in: room) }
        dataController.process(events: joinedRoom.timeline?.events, in: room, paginating: .forwards)
        
        dataController.save()
        
        // then there should be one room, one member and one message created
        XCTAssertEqual(dataController.count(for: Room.fetchRequest()), 1, "There should be 1 room.")
        XCTAssertEqual(dataController.count(for: Member.fetchRequest()), 1, "There should be 1 member.")
        XCTAssertEqual(dataController.count(for: Message.fetchRequest()), 1, "There should be 1 message.")
        XCTAssertEqual(dataController.count(for: Reaction.fetchRequest()), 1, "There should be 1 reaction.")
    }
    
    func testLoadMessageWithExistingReaction() throws {
        // given a single room with a reaction that created a template message for its relationship
        try testNewJoinedRoomWithReaction()
        let room = dataController.room(id: "!test:example.org")!
        XCTAssertNil(room.lastMessage?.body, "The shouldn't have any content yet.")
        
        // when more messages are loaded in the room, including the event for the template message
        let dict = try loadJSON(named: "LoadMessages", as: MessagesResponse.self)
        let events = dict.events!
        
        // reversed events to create messages before any relations create them
        dataController.process(events: events, in: room, paginating: .backwards)
        room.previousBatch = dict.endToken
        
        self.dataController.save()
        
        // then there should be one room, with two members, two messages and a single reaction
        XCTAssertEqual(dataController.count(for: Room.fetchRequest()), 1, "There should be 1 room.")
        XCTAssertEqual(dataController.count(for: Member.fetchRequest()), 2, "There should be 2 members.")
        XCTAssertEqual(dataController.count(for: Message.fetchRequest()), 1, "There should be 1 message.")
        XCTAssertEqual(dataController.count(for: Reaction.fetchRequest()), 1, "There should be 1 reaction.")
        
        
        // then the room's last message content should be updated
        XCTAssertEqual(room.lastMessage?.body, "Original message", "The message should match the content from the pagination response.")
        XCTAssertEqual(room.lastMessage?.lastEdit?.body, "Edited message", "The message should contain the edit from the pagination response.")
        XCTAssertEqual(room.lastMessage?.aggregatedReactions(for: "").count, 1, "The message should have the reaction from the original sync response.")
    }
}
