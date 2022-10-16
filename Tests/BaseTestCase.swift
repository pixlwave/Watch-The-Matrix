import XCTest
@testable import Watch_The_Matrix_WatchKit_App
@testable import Matrix

class BaseTestCase: XCTestCase {
    var dataController: DataController!
    var jsonDecoder: JSONDecoder!
    
    enum TestError: Error {
        case missingFile
    }

    override func setUpWithError() throws {
        dataController = DataController(inMemory: true)
        jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .millisecondsSince1970
        jsonDecoder.userInfo[.roomEventTypes] = Client.eventTypes
    }
    
    func loadJSON<T: Decodable>(named fileName: String, `as` type: T.Type) throws -> T {
        guard let url = Bundle(for: Self.self).url(forResource: fileName, withExtension: "json") else {
            throw TestError.missingFile
        }
        
        let data = try Data(contentsOf: url)
        return try jsonDecoder.decode(T.self, from: data)
    }
}
