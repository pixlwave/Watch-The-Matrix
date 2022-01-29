import SwiftUI
import Matrix

/// A view that displays all of the rooms that the user is currently joined to.
struct RootView: View {
    @EnvironmentObject var matrix: MatrixController
    
    // sheets and alerts
    @State private var presentedRoom: Room?
    @State private var isPresentingSettings = false
    @State private var syncError: MatrixError? = nil
    
    @Environment(\.managedObjectContext) var viewContext
    @FetchRequest(entity: Room.entity(),
                  sortDescriptors: [NSSortDescriptor(keyPath: \Room.lastMessageDate, ascending: false)],
                  predicate: NSPredicate(format: "isSpace != true"),
                  animation: .default) var rooms: FetchedResults<Room>
    
    /// A binding to `presentedRoom` that controls the navigation link.
    var isPresentingRoom: Binding<Bool> {
        Binding {
            presentedRoom != nil
        } set: { newValue in
            guard !newValue else { return }
            presentedRoom = nil
        }
    }
    
    var body: some View {
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
            
            ForEach(rooms) { room in
                Button { presentedRoom = room } label: {
                    RoomCell(room: room)
                }
                .disabled(room.isEncrypted)
            }
        }
        .navigationTitle("Rooms")
        .background(
            // Use a hidden navigation link to fix links in a list popping when
            // a new sort order moves the currently selected cell offscreen.
            NavigationLink("", isActive: isPresentingRoom) {
                presentedRoom.map { room in
                    RoomView(room: room)
                        .environmentObject(matrix)
                        .environment(\.managedObjectContext, viewContext)
                }
            }
            .hidden()
        )
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { isPresentingSettings = true } label: {
                    Image(systemName: "person")
                }
            }
        }
        .sheet(isPresented: $isPresentingSettings) {
            SettingsView()
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
