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
                        Text(event.sender)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .id(event.id)
                    .listRowPlatterColor(event.isMe ? nil : .purple)
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
