import SwiftUI
import Matrix

struct RootView: View {
    @EnvironmentObject var matrix: MatrixController
    @State var isPresentingSignOutAlert = false
    
    @FetchRequest(entity: Room.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \Room.name, ascending: true)], animation: .default) var rooms: FetchedResults<Room>
    @Environment(\.managedObjectContext) var viewContext
    
    var body: some View {
        let sortedRooms = rooms.sorted { room1, room2 in
            let date1 = room1.lastMessage?.date ?? Date(timeIntervalSince1970: 0)
            let date2 = room2.lastMessage?.date ?? Date(timeIntervalSince1970: 0)
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
    @EnvironmentObject var matrix: MatrixController
    
    var lastMessageBody: String {
        guard let lastMessage = room.lastMessage else { return "" }
        return lastMessage.lastEdit?.body ?? lastMessage.body ?? ""
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                if room.unreadCount > 0 {
                    Text(Image(systemName: "circlebadge.fill"))
                        .imageScale(.small)
                        .foregroundColor(.purple)
                }
                Text(room.name ?? room.generateName(for: matrix.userID))
            }
            
            Text(lastMessageBody)
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
