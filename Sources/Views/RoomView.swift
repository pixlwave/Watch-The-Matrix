import SwiftUI
import Matrix
import CoreData

/// A view that shows the messages of a room.
struct RoomView: View {
    @Environment(MatrixController.self) private var matrix
    @ObservedObject var room: Room
    let transactionStore: TransactionStore
    
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
        
        // observe outgoing transactions to display local echoes
        transactionStore = room.transactionStore
    }
    
    var body: some View {
        // show the name of the message sender when there are more than 2 people in the room
        let showSenders = room.joinedMemberCount > 2
        
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if room.hasMoreMessages {
                        Button("Load More…") {
                            matrix.loadMoreMessages(in: room)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    // make sure to identify using the message otherwise image state is lost when new
                    // messages get added to the fetch results
                    ForEach(Array(messages.enumerated()), id: \.element) { index, message in
                        // figure out whether the sender's name is the same to avoid duplicate labels
                        let previousMessage = messages.indices.contains(index - 1) ? messages[index - 1] : nil
                        let senderHasChanged = previousMessage?.sender != message.sender
                        let isCurrentUser = message.sender?.id == matrix.userID
                        
                        // hide the message if it has been redacted
                        if !message.isRedacted {
                            MessageView(message: message,
                                        showSender: showSenders ? senderHasChanged : false,
                                        isCurrentUser: isCurrentUser)
                            .id(message.id)     // give the view its message's id for programatic scrolling
                            .onTapGesture(count: 2) { messageToReactTo = message }
                            .onLongPressGesture { messageToReactTo = message }
                            .transition(.move(edge: .bottom))
                        } else {
                            Label("Deleted", systemImage: "trash")
                                .padding()
                                .background {
                                    RoundedRectangle(cornerRadius: 6)
                                        .foregroundColor(Color(.darkGray).opacity(1 / 3))
                                }
                                .id(message.id) // give the view it's message's id for programatic scrolling
                        }
                    }
                    
                    // show a local echo for outgoing messages
                    ForEach(transactionStore.messages) { transaction in
                        MessageAligner(isCurrentUser: true) {
                            MessageTransactionView(transaction: transaction)
                        }
                    }
                    
                    MessageComposer(room: room)
                        .padding(.top)
                }
                .navigationTitle(room.name ?? room.generateName(for: matrix.userID))
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    guard !hasAppeared else { return }
                    
                    // update the last message id and display the last message
                    lastMessageID = messages.last?.id
                    reader.scrollTo(lastMessageID, anchor: .bottom)
                    
                    // mark the last message in the room as read
                    markRoomAsRead()
                    
                    // prevent the closure from running after the reaction sheet has been shown
                    hasAppeared = true
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
                .sheet(item: $messageToReactTo) { message in
                    ReactionPicker(message: message, room: room)
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
        NavigationStack {
            RoomView(room: matrix.dataController.room(id: "!test0:example.org")!)
                .environment(matrix)
                .environment(\.managedObjectContext, matrix.dataController.viewContext)
        }
    }
}
