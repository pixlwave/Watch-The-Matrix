import SwiftUI
import Matrix

struct RootView: View {
    @EnvironmentObject var matrix: Chat
    @State var isPresentingSignOutAlert = false
    
    @FetchRequest(entity: Room.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \Room.name, ascending: true)], animation: .default) var rooms: FetchedResults<Room>
    @Environment(\.managedObjectContext) var viewContext
    
    var body: some View {
        let sortedRooms = rooms.sorted { room1, room2 in
            let date1 = (try? viewContext.fetch(room1.lastMessageRequest).first?.date) ?? Date(timeIntervalSince1970: 0)
            let date2 = (try? viewContext.fetch(room2.lastMessageRequest).first?.date) ?? Date(timeIntervalSince1970: 0)
            return date1 > date2
        }
        
        List(sortedRooms) { room in
            NavigationLink(destination: RoomView(room: room)
                            .environmentObject(matrix)
                            .environment(\.managedObjectContext, viewContext)) {
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
    
    @Environment(\.managedObjectContext) var viewContext
    @FetchRequest<Message> var lastMessage: FetchedResults<Message>
    
    init(room: Room) {
        self.room = room
        _lastMessage = FetchRequest(fetchRequest: room.lastMessageRequest)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(room.name ?? room.generateName(for: matrix.userID))
            Text(lastMessageBody() ?? "")
                .lineLimit(1)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
    
    func lastMessageBody() -> String? {
        guard let lastMessage = lastMessage.first else { return nil }
        
        if let edit = (try? viewContext.fetch(lastMessage.lastEditRequest))?.first {
            return edit.body
        } else {
            return lastMessage.body
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
