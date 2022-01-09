import XCTest
import Matrix
@testable import Watch_The_Matrix_WatchKit_Extension

class RedactionTests: BaseTestCase {
    func testRedactingMessage() throws {
        // given an un-redacted message from the sample data set
        try dataController.createSampleData()
        
        let message = dataController.room(id: "!test0:example.org")!.lastMessage!
        XCTAssertFalse(message.isRedacted, "The message should not be redacted.")
        
        // when redacting that message
        message.isRedacted = true
        dataController.save()
        
        // then the message should indicate it has been redacted
        XCTAssertTrue(message.isRedacted, "The message should be redacted.")
    }
    
    func testRedactingReaction() throws {
        // given a message with 1 reaction from the sample data set
        try dataController.createSampleData()
        let room = dataController.room(id: "!test0:example.org")!
        let message = room.lastMessage!
        XCTAssertEqual(message.aggregatedReactions(for: "").count, 1, "The message should have 1 reaction.")
        
        // when redacting that reaction
        let joinedRoom = try loadJSON(named: "JoinedRoom-ReactionRedaction", as: JoinedRoom.self)
        dataController.process(events: joinedRoom.timeline?.events, in: room, paginating: .forwards)
        dataController.save()
        
        // then the message should indicate it has been redacted
        XCTAssertEqual(message.aggregatedReactions(for: "").count, 0, "The message shouldn't have any reactions.")
    }
    
    func testProcessingMessageWithPendingRedaction() throws {
        // given a room with a single redaction whose event hasn't been synced
        let room = Room(context: dataController.viewContext)
        room.id = "!test0:example.org"
        
        let redaction = Redaction(context: dataController.viewContext)
        redaction.id = "redact_last_message"
        redaction.date = Date()
        redaction.eventID = "m23456"
        redaction.room = room
        dataController.save()
        XCTAssertEqual(dataController.count(for: Redaction.fetchRequest()), 1, "There should be 1 pending redaction.")
        
        // when receiving that message
        let joinedRoom = try loadJSON(named: "SyncMessageJoinedRoom", as: JoinedRoom.self)
        dataController.process(events: joinedRoom.timeline?.events, in: room, paginating: .backwards)
        
        // then the message should be marked as redacted and the pending redaction should be deleted
        let message = dataController.message(id: "m23456")!
        XCTAssertTrue(message.isRedacted, "The message should be redacted.")
        XCTAssertEqual(dataController.count(for: Redaction.fetchRequest()), 0, "The pending redaction should have been deleted.")
    }
}
