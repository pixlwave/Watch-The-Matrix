import Matrix
import CoreData

extension Member {
    convenience init(userID: String, context: NSManagedObjectContext) {
        self.init(context: context)
        self.id = userID
    }
    
    convenience init(event: StateEvent, context: NSManagedObjectContext) {
        self.init(context: context)
        
        self.id = event.stateKey
        self.displayName = event.content.displayName
        
        if let urlString = event.content.avatarURL, var components = URLComponents(string: urlString) {
            components.scheme = "https"
            self.avatarURL = components.url
        } else {
            self.avatarURL = nil
        }
    }
}
