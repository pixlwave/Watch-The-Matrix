import XCTest
@testable import Watch_The_Matrix_WatchKit_App

class MemberTests: BaseTestCase {
    func testMemberConstraints() {
        // given two rooms the same user as a member of both
        let roomA = Room(context: dataController.viewContext)
        let roomB = Room(context: dataController.viewContext)
        roomA.id = "!testA:example.org"
        roomB.id = "!testB:example.org"
        
        _ = dataController.createMember(id: "@user:example.org", in: roomA)
        _ = dataController.createMember(id: "@user:example.org", in: roomB)
        dataController.save()
        
        XCTAssertEqual(dataController.count(for: Member.fetchRequest()), 2, "There should be 2 members in total")
        
        // when re-creating the same user as a member of one of the existing rooms
        _ = dataController.createMember(id: "@user:example.org", in: roomB)
        dataController.save()
        
        // then the constraints should prevent a third member from being created
        XCTAssertEqual(dataController.count(for: Member.fetchRequest()), 2, "There should be 2 members in total")
        
        // when creating a different user as a member of one of the existing rooms
        _ = dataController.createMember(id: "@user2:example.org", in: roomB)
        dataController.save()
        
        // then an additional member should be created
        XCTAssertEqual(dataController.count(for: Member.fetchRequest()), 3, "There should be 3 members in total")
    }
}
