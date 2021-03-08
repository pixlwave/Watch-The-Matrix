import SwiftUI
import Matrix

struct RootView: View {
    @EnvironmentObject var matrix: Chat
    @State var isPresentingSignOutAlert = false
    
    @FetchRequest(entity: Room.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \Room.name, ascending: true)], animation: .default) var rooms: FetchedResults<Room>
    @Environment(\.managedObjectContext) var managedObjectContext
    
    var body: some View {
        let sortedRooms = rooms.sorted { room1, room2 in
            let date1 = (try? managedObjectContext.fetch(room1.lastMessageRequest).first?.date) ?? Date(timeIntervalSince1970: 0)
            let date2 = (try? managedObjectContext.fetch(room2.lastMessageRequest).first?.date) ?? Date(timeIntervalSince1970: 0)
            return date1 > date2
        }
        
        List(sortedRooms) { room in
            NavigationLink(destination: RoomView(room: room)
                            .environmentObject(matrix)
                            .environment(\.managedObjectContext, managedObjectContext)) {
                RoomCell(room: room)
            }
        }
        .navigationTitle("Rooms")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { matrix.createRoom(name: "Test")} label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button { isPresentingSignOutAlert = true } label: {
                    Image(systemName: "person")
                }
            }
        }
        .alert(isPresented: $isPresentingSignOutAlert) {
            Alert(title: Text("Sign Out?"),
                  primaryButton: .destructive(Text("Sign out")) {
                    matrix.logout()
                  },
                  secondaryButton: .cancel()
            )
        }
    }
}

struct RoomCell: View {
    @ObservedObject var room: Room
    @EnvironmentObject var matrix: Chat
    
    @FetchRequest<Message> var lastMessage: FetchedResults<Message>
    
    init(room: Room) {
        self.room = room
        _lastMessage = FetchRequest(fetchRequest: room.lastMessageRequest)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(room.name ?? room.generateName(for: matrix.userID))
            Text(lastMessage.first?.body ?? "")
                .lineLimit(1)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
