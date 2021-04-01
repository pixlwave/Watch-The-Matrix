import SwiftUI
import Matrix
import CoreData

/// A view that shows the messages of a room.
struct RoomView: View {
    @EnvironmentObject var matrix: MatrixController
    @ObservedObject var room: Room
    
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
            List {
                if room.hasMoreMessages {
                    Button("Load More…") {
                        matrix.loadMoreMessages(in: room)
                    }
                }
                
                ForEach(messages) { message in
                    // hide the message if it has been redacted
                    if !message.isRedacted {
                        MessageView(message: message, showSender: showSenders)
                            .listRowPlatterColor(message.sender?.id == matrix.userID ? .purple : Color(.darkGray))
                            .onLongPressGesture { messageToReactTo = message }
                    } else {
                        Label("Deleted", systemImage: "trash")
                    }
                }
            }
            .navigationTitle(room.name ?? room.generateName(for: matrix.userID))
            .onAppear {
                // update the last message id and display the last message
                lastMessageID = messages.last?.id
                reader.scrollTo(lastMessageID, anchor: .bottom)
                
                // mark the last message in the room as read
                markRoomAsRead()
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
                // displays a two column reaction picker with 6 emoji to choose from
                LazyVGrid(columns: [GridItem(), GridItem()]) {
                    ForEach(["👍", "👎", "😄", "😭", "❤️", "🤯"], id: \.self) { reaction in
                        Button {
                            matrix.sendReaction(reaction, to: message, in: room)
                            messageToReactTo = nil
                        } label: {
                            Text(reaction)
                                .font(.system(size: 21))
                        }
                    }
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
    static var previews: some View {
        List {
            VStack(alignment: .leading) {
                Text("Hello, World!")
                Text("@me:server.net")
                    .font(.footnote)
                    .foregroundColor(Color.primary.opacity(0.667))
//                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .listRowPlatterColor(Color(.darkGray))
            
            VStack(alignment: .leading) {
                Text("A slightly longer message")
                Text("@them:sever-1234-sddf.org")
                    .font(.footnote)
                    .foregroundColor(Color.primary.opacity(0.667))
//                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .listRowPlatterColor(.purple)
        }
    }
}
