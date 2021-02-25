import SwiftUI
import Matrix

struct RoomView: View {
    @EnvironmentObject var matrix: Client
    @ObservedObject var room: Room
    
    @State var eventToReactTo: Event?
    
    var body: some View {
        ScrollViewReader { reader in
            List {
                ForEach(room.events) { event in
                    VStack(alignment: .leading) {
                        Text(event.body)
                        if !event.isMe && room.members.count > 2 {
                            Text(event.sender)
                                .font(.footnote)
                                .foregroundColor(Color.primary.opacity(0.667))
                        }
                    }
                    .id(event.id)
                    .listRowPlatterColor(event.isMe ? Color(.darkGray) : .purple)
                    .onLongPressGesture {
                        eventToReactTo = event
                    }
                }
            }
            .navigationTitle(room.name ?? "")
            .onAppear {
                reader.scrollTo(room.events.last?.id, anchor: .bottom)
            }
            .onChange(of: room.events) { events in
                withAnimation {
                    reader.scrollTo(events.last?.id, anchor: .bottom)
                }
            }
            .sheet(item: $eventToReactTo) { event in
                LazyVGrid(columns: [GridItem(), GridItem()]) {
                    ForEach(["👍", "👎", "😄", "😭", "❤️", "🤯"], id: \.self) { reaction in
                        Button {
                            matrix.sendReaction(text: reaction, to: eventToReactTo!.id, in: room.id)
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
