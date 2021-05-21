import SwiftUI
import Matrix
import CoreData

/// A view that shows the messages of a room.
struct RoomView: View {
    @EnvironmentObject var matrix: MatrixController
    @ObservedObject var room: Room
    
    /// A boolean indicating  whether `.onAppear` has been called.
    @State private var hasAppeared = false
    /// The id of the last message in the room. This is stored to determine whether new messages
    /// have been added to the the room from a sync operation or a back pagination.
    @State private var lastMessageID: String?
    @State private var messageToReactTo: Message?
    
    @FetchRequest<Message> var messages: FetchedResults<Message>
    
    init(room: Room) {
        self.room = room
        _messages = FetchRequest(fetchRequest: room.messagesRequest, animation: .default)
    }
    
    var body: some View {
        // show the name of the message sender when there are more than 2 people in the room
        let showSenders = room.memberCount > 2
        
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if room.hasMoreMessages {
                        Button("Load More…") {
                            matrix.loadMoreMessages(in: room)
                        }
                    }
                    
                    ForEach(messages.indices, id: \.self) { index in
                        let message = messages[index]
                        
                        // figure out whether the sender's name is the same to avoid duplicate labels
                        let previousMessage = messages.indices.contains(index - 1) ? messages[index - 1] : nil
                        let senderHasChanged = previousMessage?.sender != message.sender
                        
                        // hide the message if it has been redacted
                        if !message.isRedacted {
                            MessageView(message: message,
                                        showSender: showSenders ? senderHasChanged : false,
                                        bubbleColor: message.sender?.id == matrix.userID ? .accentColor : Color(.darkGray)
                            )
                            .onLongPressGesture { messageToReactTo = message }
                            .transition(.move(edge: .bottom))
                        } else {
                            Label("Deleted", systemImage: "trash")
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 6).foregroundColor(Color(.darkGray).opacity(1 / 3)))
                        }
                    }
                    
                    MessageComposer(room: room)
                }
                .navigationTitle(room.name ?? room.generateName(for: matrix.userID))
                .onAppear {
                    if !hasAppeared {
                        // update the last message id and display the last message
                        lastMessageID = messages.last?.id
                        reader.scrollTo(lastMessageID, anchor: .bottom)
                        
                        // mark the last message in the room as read
                        markRoomAsRead()
                        
                        // prevent the closure from running after the reaction sheet has been shown
                        hasAppeared = true
                    }
                }
                .onReceive(messages.publisher) { _ in
                    // if a more recent message has been added, show that message
                    #warning("This should additionally check whether the last message is on screen.")
                    if messages.last?.id != lastMessageID {
                        withAnimation {
                            lastMessageID = messages.last?.id
                            reader.scrollTo(lastMessageID, anchor: .bottom)
                        }
                    }
                    
                    // keep the room marked as read
                    // outside of the condition above to include edits to the last message
                    markRoomAsRead()
                }
                .sheet(item: $messageToReactTo) { _ in
                    ReactionPicker(message: $messageToReactTo)
                }
            }
        }
    }
    
    /// Sends a read receipt for the last message in the room when the room has an unread count.
    func markRoomAsRead() {
        guard room.unreadCount > 0, let lastMessage = room.lastMessage else { return }
        matrix.sendReadReceipt(for: lastMessage, in: room)
    }
}

struct RoomView_Previews: PreviewProvider {
    static let matrix = MatrixController.preview
    
    static var previews: some View {
        NavigationView {
            RoomView(room: matrix.dataController.room(id: "!test0:example.org")!)
                .environmentObject(matrix)
                .environment(\.managedObjectContext, matrix.dataController.viewContext)
        }
    }
}
