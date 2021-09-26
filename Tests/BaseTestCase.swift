import XCTest
@testable import Watch_The_Matrix_WatchKit_Extension
@testable import Matrix

class BaseTestCase: XCTestCase {
    var dataController: DataController!
    var jsonDecoder: JSONDecoder!

    override func setUpWithError() throws {
        dataController = DataController(inMemory: true)
        jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .millisecondsSince1970
        jsonDecoder.userInfo[.roomEventTypes] = Client.eventTypes
    }
    
    func loadJoinedRoomJSON(named fileName: String) -> JoinedRoom? {
        guard
            let url = Bundle(for: Self.self).url(forResource: fileName, withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else { return nil }
        
        return try? jsonDecoder.decode(JoinedRoom.self, from: data)
    }
}
