import SwiftUI
import Matrix

/// A view that displays all of the rooms that the user is currently joined to.
struct RootView: View {
    @EnvironmentObject var matrix: MatrixController
    
    // sheets and alerts
    @State private var isPresentingSignOutAlert = false
    @State private var syncError: MatrixError? = nil
    
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
        
        List {
            if case let .syncError(error) = matrix.state {
                Button { syncError = error } label: {
                    HStack {
                        Spacer()
                        Text("Sync Error")
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                }
            }
            
            ForEach(sortedRooms) { room in
                NavigationLink(destination: RoomView(room: room)
                                .environmentObject(matrix)
                                .environment(\.managedObjectContext, viewContext)) {
                    RoomCell(room: room)
                }
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
        .sheet(item: $syncError) { syncError in
            Text(syncError.description)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static let matrix = MatrixController.preview
    
    static var previews: some View {
        NavigationView {
            RootView()
                .environmentObject(matrix)
                .environment(\.managedObjectContext, matrix.dataController.viewContext)
        }
    }
}
