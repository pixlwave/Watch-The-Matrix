import Combine
import Matrix

/// A class that represents a transaction for outbound messages.
class MessageTransaction: ObservableObject, Identifiable {
    /// The transaction ID used when sending the message.
    let id: String
    /// The content of the message.
    let message: String
    /// The ID of the room that the message is for.
    let roomID: String
    
    /// A cancellable token for the send operation.
    var token: AnyCancellable?
    /// The event ID created by the server if the message was sent successfully.
    @Published var eventID: String?
    /// An error that occured when sending the message, otherwise nil.
    @Published var error: MatrixError?
    
    var isDelivered: Bool {
        eventID != nil
    }
    
    init(id: String, message: String, roomID: String) {
        self.id = id
        self.message = message
        self.roomID = roomID
    }
}
