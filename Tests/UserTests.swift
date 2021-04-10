import XCTest
@testable import TestingHost

class UserTests: BaseTestCase {
    func testConstraints() {
        func testUsers() {
            // given two rooms with the same user in both rooms
            let roomA = Room(context: dataController.viewContext)
            let roomB = Room(context: dataController.viewContext)
            roomA.id = "!testA:example.org"
            roomB.id = "!testB:example.org"
            
            _ = dataController.createMember(id: "@user:example.org", in: roomA)
            _ = dataController.createMember(id: "@user:example.org", in: roomB)
            dataController.save()
            
            XCTAssertEqual(dataController.count(for: Member.fetchRequest()), 2, "There should be 2 users in total")
            
            // when re-creating the same user in one of the existing rooms
            _ = dataController.createMember(id: "@user:example.org", in: roomB)
            dataController.save()
            
            // then the constraints should prevent a third user from being created
            XCTAssertEqual(dataController.count(for: Member.fetchRequest()), 2, "There should be 2 users in total")
            
            // when creating a different user in one of the existing rooms
            _ = dataController.createMember(id: "@user2:example.org", in: roomB)
            dataController.save()
            
            // then this user should be created
            XCTAssertEqual(dataController.count(for: Member.fetchRequest()), 3, "There should be 3 users in total")
        }
    }
}
