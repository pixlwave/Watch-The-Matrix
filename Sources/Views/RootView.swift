import SwiftUI
import Matrix

/// A view that displays all of the rooms that the user is currently joined to.
struct RootView: View {
    @EnvironmentObject var matrix: MatrixController
    @State var isPresentingSignOutAlert = false
    
    @Environment(\.managedObjectContext) var viewContext
    @FetchRequest(entity: Room.entity(),
                  sortDescriptors: [NSSortDescriptor(keyPath: \Room.name, ascending: true)],
                  animation: .default) var rooms: FetchedResults<Room>
    
    var body: some View {
        // sort the rooms by the date of the last message, newest at the top
        // when the room has no content push it to the end of the list
        // core data appears to lack the ability to do this in the fetch request
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

/// A view that displays a room's title and the last message in the room along with
/// an indication of whether the room has an unread messages.
struct RoomCell: View {
    @ObservedObject var room: Room
    @EnvironmentObject var matrix: MatrixController
    
    /// The body of the last message, taking into account any edits. This will return
    /// an empty string if there isn't a valid body to return.
    var lastMessageBody: String {
        guard let lastMessage = room.lastMessage else { return "" }
        return lastMessage.lastEdit?.body ?? lastMessage.body ?? ""
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                // show a badge before the name if there are any unread messages
                if room.unreadCount > 0 {
                    Image(systemName: "circlebadge.fill")
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
