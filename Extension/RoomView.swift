import SwiftUI
import Matrix

struct RoomView: View {
    @EnvironmentObject var matrix: Client
    @ObservedObject var room: Room
    
    @State private var shouldScroll = false
    @State private var eventToReactTo: Event?
    
    var body: some View {
        ScrollViewReader { reader in
            List {
                if room.hasMoreMessages {
                    Button("Load More…") {
                        matrix.loadMoreMessages(in: room)
                    }
                }
                
                ForEach(room.events) { event in
                    VStack(alignment: .leading) {
                        Text(event.body)
                        if !event.isMe && room.members.count > 2 {
                            Text(displayName(for: event.sender))
                                .font(.footnote)
                                .foregroundColor(Color.primary.opacity(0.667))
                        }
                    }
                    .id(event.id)
                    .listRowPlatterColor(event.isMe ? .purple : Color(.darkGray))
                    .onLongPressGesture {
                        eventToReactTo = event
                    }
                }
            }
            .navigationTitle(room.name ?? "")
            .onAppear {
                reader.scrollTo(room.events.last?.id, anchor: .bottom)
            }
            .onReceive(room.$events) { newValue in
                shouldScroll = newValue.last != room.events.last
            }
            .onChange(of: room.events) { events in
                guard shouldScroll else { return }
                withAnimation {
                    reader.scrollTo(events.last?.id, anchor: .bottom)
                }
            }
            .sheet(item: $eventToReactTo) { event in
                LazyVGrid(columns: [GridItem(), GridItem()]) {
                    ForEach(["👍", "👎", "😄", "😭", "❤️", "🤯"], id: \.self) { reaction in
                        Button {
                            matrix.sendReaction(text: reaction, to: eventToReactTo!, in: room)
                            eventToReactTo = nil
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
        room.members.first { $0.userID == userID }?.displayName ?? userID
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
