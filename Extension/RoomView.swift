import SwiftUI
import Matrix
import CoreData

struct RoomView: View {
    @EnvironmentObject var matrix: Chat
    @ObservedObject var room: Room
    
    @State private var shouldScroll = false
    @State private var messageToReactTo: Message?
    
    @FetchRequest<Message> var messages: FetchedResults<Message>
    
    init(room: Room) {
        self.room = room
        _messages = FetchRequest(fetchRequest: room.messagesRequest, animation: .default)
    }
    
    var body: some View {
        let showsSenders = room.allMembers.count > 2
        
        ScrollViewReader { reader in
            List {
                if room.hasMoreMessages {
                    Button("Load More…") {
                        matrix.loadMoreMessages(in: room)
                    }
                }
                
                ForEach(messages) { message in
                    VStack(alignment: .leading) {
                        Text(message.body ?? "")
                        if showsSenders {
                            Text(message.sender?.displayName ?? message.sender?.id ?? "")
                                .font(.footnote)
                                .foregroundColor(Color.primary.opacity(0.667))
                        }
                    }
                    .id(message.id)
                    .listRowPlatterColor(message.sender?.id == matrix.userID ? .purple : Color(.darkGray))
                    .onLongPressGesture {
                        messageToReactTo = message
                    }
                }
            }
            .navigationTitle(room.name ?? room.generateName(for: matrix.userID))
            .onAppear {
                reader.scrollTo(messages.last?.id, anchor: .bottom)
            }
//            .onReceive(room.$events) { newValue in
//                shouldScroll = newValue.last != room.lastMessage
//            }
//            .onChange(of: messages) { messages in
//                guard shouldScroll else { return }
//                withAnimation {
//                    reader.scrollTo(messages.last?.id, anchor: .bottom)
//                }
//            }
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
