import XCTest
import Matrix
@testable import Watch_The_Matrix_WatchKit_App

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
            if i == 0 {
                let member = Member(context: dataController.viewContext)
                member.id = "@reactiontest:example.org"
                reaction.sender = member
            }
        }
        
        for i in 0..<2 {
            let reaction = Reaction(context: dataController.viewContext)
            reaction.id = "reactionB\(i)"
            reaction.key = "🙃"
            reaction.date = Date()
            reaction.message = message
        }
        
        dataController.save()
        
        let aggregatedReactions = message?.aggregatedReactions(for: "@reactiontest:example.org") ?? []
        
        XCTAssertEqual(aggregatedReactions.count, 2, "There should be 2 unique reactions to the message.")
        XCTAssertEqual(aggregatedReactions[0].count, 3, "There should be 3 👋 reactions to the message.")
        XCTAssertEqual(aggregatedReactions[1].count, 2, "There should be 2 🙃 reactions to the message.")
        XCTAssertNotNil(aggregatedReactions[0].eventIDToRedact, "The 👋 reaction should have an event ID for the user.")
        XCTAssertNil(aggregatedReactions[1].eventIDToRedact, "The 🙃 reaction should not have an event ID for the user.")
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
    
    func testFormattingMessageAsReply() throws {
        try dataController.createSampleData()
        
        // given a set of message events that reply to a message event
        let room = dataController.room(id: "!test0:example.org")!
        let messages = try loadJSON(named: "MessageReplies", as: [RoomMessageEvent].self)
        
        // when loading the events as messages
        let rootMessage = dataController.createMessage(id: messages[0].eventID)
        dataController.updateMessage(rootMessage, from: messages[0], in: room)
        let richReply = dataController.createMessage(id: messages[1].eventID)
        dataController.updateMessage(richReply, from: messages[1], in: room)
        dataController.save()
        
        // then the messages should be correctly identified as replies and formatted appropriately
        XCTAssertFalse(rootMessage.isReply, "The root message should not be a reply.")
        XCTAssertNil(rootMessage.replyQuote, "The root message should not have a reply quote.")
        XCTAssertEqual(rootMessage.body, "Hello, World!", "The root message body should not be altered.")
        
        XCTAssertTrue(richReply.isReply, "The message with rich reply content should be a reply.")
        XCTAssertEqual(richReply.replyQuote, "Hello, World!", "The reply quote from the rich reply should contain the original message.")
        XCTAssertEqual(richReply.body, "This message is a reply.", "The message body should only contain the reply content from the rich reply.")
    }
}
