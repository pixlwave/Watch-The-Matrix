import SwiftUI
import Matrix
import CoreData

struct RoomView: View {
    @EnvironmentObject var matrix: Chat
    @ObservedObject var room: Room
    
    @State private var lastMessageID: String?
    @State private var messageToReactTo: Message?
    
    @FetchRequest<Message> var messages: FetchedResults<Message>
    
    init(room: Room) {
        self.room = room
        _messages = FetchRequest(fetchRequest: room.messagesRequest, animation: .default)
    }
    
    var body: some View {
        let showSenders = room.allMembers.count > 2
        
        ScrollViewReader { reader in
            List {
                if room.hasMoreMessages {
                    Button("Load More…") {
                        matrix.loadMoreMessages(in: room)
                    }
                }
                
                ForEach(messages) { message in
                    if message.redactions?.count == 0 {
                        MessageView(message: message, showSender: showSenders)
                            .listRowPlatterColor(message.sender?.id == matrix.userID ? .purple : Color(.darkGray))
                            .onLongPressGesture {
                                messageToReactTo = message
                            }
                    } else {
                        Label("Deleted", systemImage: "trash")
                    }
                }
            }
            .navigationTitle(room.name ?? room.generateName(for: matrix.userID))
            .onAppear {
                lastMessageID = messages.last?.id
                reader.scrollTo(lastMessageID, anchor: .bottom)
            }
            .onReceive(messages.publisher) { newValue in
                if messages.last?.id != lastMessageID {
                    withAnimation {
                        lastMessageID = messages.last?.id
                        reader.scrollTo(lastMessageID, anchor: .bottom)
                    }
                }
            }
            .sheet(item: $messageToReactTo) { message in
                LazyVGrid(columns: [GridItem(), GridItem()]) {
                    ForEach(["👍", "👎", "😄", "😭", "❤️", "🤯"], id: \.self) { reaction in
                        Button {
                            matrix.sendReaction(text: reaction, to: message, in: room)
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
    
    func displayName(for userID: String) -> String {
        room.allMembers.first { $0.id == userID }?.displayName ?? userID
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
