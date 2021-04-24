import SwiftUI
import CoreData

extension RoomView {
    class ViewModel: NSObject, ObservableObject, NSFetchedResultsControllerDelegate {
        private let room: Room
        private let matrix: MatrixController
        private let roomsController: NSFetchedResultsController<Message>
        
        /// All available messages in the room.
        @Published var messages = [Message]()
        
        /// The id of the last message in the room. This is stored to determine whether new messages
        /// were added to the the room from a sync operation or a back pagination.
        var lastMessageID: String?
        
        /// A boolean that becomes true when the `lastMessageID` has changed.
        @Published var hasNewMessages = false
        
        init(room: Room, matrix: MatrixController) {
            self.room = room
            self.matrix = matrix
            
            roomsController = NSFetchedResultsController(fetchRequest: room.messagesRequest,
                                                         managedObjectContext: matrix.dataController.viewContext,
                                                         sectionNameKeyPath: nil,
                                                         cacheName: nil)
            
            
            super.init()
            
            roomsController.delegate = self
            
            do {
                try roomsController.performFetch()
                
                messages = roomsController.fetchedObjects ?? []
                lastMessageID = messages.last?.id
            } catch {
                print("Failed to fetch messages.")
            }
        }
        
        /// Sends a read receipt for the last message in the room when the room has an unread count.
        func markRoomAsRead() {
            guard room.unreadCount > 0, let lastMessage = room.lastMessage else { return }
            matrix.sendReadReceipt(for: lastMessage, in: room)
        }
        
        func loadMoreMessages() {
            matrix.loadMoreMessages(in: room)
        }
        
        
        // MARK: NSFetchedResultsControllerDelegate
        func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
            if let newMessages = controller.fetchedObjects as? [Message] {
                withAnimation {
                    messages = newMessages
                }
                
                // update the last message id if it's changes and indicate there are new messages
                if messages.last?.id != lastMessageID {
                    lastMessageID = messages.last?.id
                    hasNewMessages = true
                }
                
                // keep the room marked as read
                // outside of the condition above to include edits to the last message
                markRoomAsRead()
            }
        }
    }
}
