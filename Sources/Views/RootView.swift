import SwiftUI
import Matrix

/// A view that displays all of the rooms that the user is currently joined to.
struct RootView: View {
    @EnvironmentObject var matrix: MatrixController
    
    // sheets and alerts
    @State private var isPresentingSettings = false
    @State private var syncError: MatrixError?
    
    @Environment(\.managedObjectContext) var viewContext
    @FetchRequest(entity: Room.entity(),
                  sortDescriptors: [NSSortDescriptor(keyPath: \Room.lastMessageDate, ascending: false)],
                  predicate: NSPredicate(format: "isSpace != true"),
                  animation: .default) var rooms: FetchedResults<Room>
    
    var body: some View {
        List {
            if case let .syncError(error) = matrix.state {
                Button { syncError = error } label: {
                    Text("Sync Error")
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            
            ForEach(rooms) { room in
                NavigationLink(value: room) {
                    RoomCell(room: room)
                }
                .disabled(room.isEncrypted)
            }
        }
        .navigationTitle("Rooms")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { isPresentingSettings = true } label: {
                    Image(systemName: "person")
                }
            }
        }
        .navigationDestination(for: Room.self) { room in
            RoomView(room: room)
                .environmentObject(matrix)
                .environment(\.managedObjectContext, viewContext)
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

struct RootView_Previews: PreviewProvider {
    static let matrix = MatrixController.preview
    
    static var previews: some View {
        NavigationStack {
            RootView()
                .environmentObject(matrix)
                .environment(\.managedObjectContext, matrix.dataController.viewContext)
        }
    }
}
