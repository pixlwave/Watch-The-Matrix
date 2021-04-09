import XCTest
@testable import TestingHost

class MessageTests: BaseTestCase {
    func testReactingToAMessage() throws {
        // given a message with no reactions from the sample data set
        try dataController.createSampleData()
        
        let message = dataController.message(id: "0190-!test0:example.org")
        XCTAssertTrue(message?.reactions?.count == 0, "The message should not have any reactions.")
        
        // when adding 5 reactions with 2 different keys
        for i in 0..<3 {
            let reaction = Reaction(context: dataController.viewContext)
            reaction.id = "reactionA\(i)"
            reaction.key = "👋"
            reaction.date = Date()
            reaction.message = message
        }
        
        for i in 0..<2 {
            let reaction = Reaction(context: dataController.viewContext)
            reaction.id = "reactionB\(i)"
            reaction.key = "🙃"
            reaction.date = Date()
            reaction.message = message
        }
        
        dataController.save()
        
        XCTAssertEqual(message?.reactionsViewModel.count, 2, "There should be 2 unique reactions to the message.")
        XCTAssertEqual(message?.reactionsViewModel[0].count, 3, "There should be 3 👋 reactions to the message.")
        XCTAssertEqual(message?.reactionsViewModel[1].count, 2, "There should be 2 🙃 reactions to the message.")
    }
    
    func testEditingAMessage() throws {
        // given an un-edited message from the sample data set
        try dataController.createSampleData()
        
        let message = dataController.room(id: "!test0:example.org")!.lastMessage!
        XCTAssertTrue(message.lastEdit == nil, "The message should not have any edits.")
        
        // when editing that message
        let edit = Edit(context: dataController.viewContext)
        edit.id = "redact_last_message"
        edit.body = "I've been edited"
        edit.date = Date()
        edit.message = message
        dataController.save()
        
        // then the message should indicate it has been redacted
        XCTAssertEqual(message.lastEdit?.body, "I've been edited", "The message should return an edit.")
    }
    
    func testRedactingMessage() throws {
        // given an un-redacted message from the sample data set
        try dataController.createSampleData()
        
        let message = dataController.room(id: "!test0:example.org")!.lastMessage!
        XCTAssertFalse(message.isRedacted, "The message should not be redacted.")
        
        // when redacting that message
        let redaction = Redaction(context: dataController.viewContext)
        redaction.id = "redact_last_message"
        redaction.date = Date()
        redaction.message = message
        dataController.save()
        
        // then the message should indicate it has been redacted
        XCTAssertTrue(message.isRedacted, "The message should be redacted.")
    }
}
