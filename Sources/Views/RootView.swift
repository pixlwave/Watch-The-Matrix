import SwiftUI
import Matrix

/// A view that displays all of the rooms that the user is currently joined to.
struct RootView: View {
    @EnvironmentObject var matrix: MatrixController
    
    // sheets and alerts
    @State private var isPresentingSettings = false
    @State private var syncError: MatrixError? = nil
    
    @Environment(\.managedObjectContext) var viewContext
    @FetchRequest(entity: Room.entity(),
                  sortDescriptors: [NSSortDescriptor(keyPath: \Room.lastMessageDate, ascending: false)],
                  predicate: NSPredicate(format: "isSpace != true"),
                  animation: .default) var rooms: FetchedResults<Room>
    
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
                NavigationLink(value: room) {
                    RoomCell(room: room)
                }
                .disabled(room.isEncrypted)
            }
        }
        .navigationTitle("Rooms")
        .navigationDestination(for: Room.self) { room in
            RoomView(room: room)
                .environmentObject(matrix)
                .environment(\.managedObjectContext, viewContext)
        }
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

#Preview {
    let matrix = MatrixController.preview
    
    NavigationStack {
        RootView()
            .environmentObject(matrix)
            .environment(\.managedObjectContext, matrix.dataController.viewContext)
    }
}
