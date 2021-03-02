import SwiftUI
import Matrix

struct RootView: View {
    @EnvironmentObject var matrix: Client
    @State var isPresentingSignOutAlert = false
    
    var body: some View {
        List(matrix.rooms) { room in
            NavigationLink(destination: RoomView(room: room).environmentObject(matrix)) {
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
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(room.name ?? room.id)
            Text(room.lastMessage()?.body ?? "")
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
