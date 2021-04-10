import XCTest
@testable import TestingHost

class DataControllerTests: BaseTestCase {
    func testSampleData() throws {
        try dataController.createSampleData()
        
        XCTAssertEqual(dataController.count(for: Room.fetchRequest()), 5, "There should be 5 rooms in the sample data.")
        XCTAssertEqual(dataController.count(for: Member.fetchRequest()), 50, "There should be 50 members in the sample data.")
        XCTAssertEqual(dataController.count(for: Message.fetchRequest()), 1000, "There should be 1000 messages in the sample data.")
        XCTAssertEqual(dataController.count(for: Reaction.fetchRequest()), 10, "There should be 10 reactions in the sample data.")
        XCTAssertEqual(dataController.count(for: Edit.fetchRequest()), 5, "There should be 5 edits in the sample data.")
        XCTAssertEqual(dataController.count(for: Redaction.fetchRequest()), 5, "There should be 5 redactions in the sample data.")
        XCTAssertEqual(dataController.count(for: SyncState.fetchRequest()), 1, "There should be sync state data.")
    }
    
    func testDeleteAll() throws {
        try testSampleData()
        
        dataController.deleteAll()
        
        XCTAssertEqual(dataController.count(for: Room.fetchRequest()), 0, "There should no rooms left over.")
        XCTAssertEqual(dataController.count(for: Member.fetchRequest()), 0, "There should be no members left over.")
        XCTAssertEqual(dataController.count(for: Message.fetchRequest()), 0, "There should be no messages left over.")
        XCTAssertEqual(dataController.count(for: Reaction.fetchRequest()), 0, "There should be no reactions left over.")
        XCTAssertEqual(dataController.count(for: Edit.fetchRequest()), 0, "There should be no edits left over.")
        XCTAssertEqual(dataController.count(for: Redaction.fetchRequest()), 0, "There should be no redactions left over.")
        XCTAssertEqual(dataController.count(for: SyncState.fetchRequest()), 0, "There should be no sync state data left over.")
    }
}
