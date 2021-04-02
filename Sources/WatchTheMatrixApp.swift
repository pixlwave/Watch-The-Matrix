import SwiftUI
import Matrix

@main
struct WatchTheMatrixApp: App {
    @StateObject var matrix = MatrixController()
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            switch matrix.state {
            case .signedOut:
                LoginView()
                    .environmentObject(matrix)
            case .initialSync:
                ProgressView()
            case .syncing, .syncError:
                NavigationView {
                    RootView()
                        .environment(\.managedObjectContext, matrix.dataController.viewContext)
                        .environmentObject(matrix)
                }
            }
        }
        .onChange(of: scenePhase, perform: updateSyncState)

        WKNotificationScene(controller: NotificationController.self, category: "myCategory")
    }
    
    /// Pauses or resumes syncing appropriately for the supplied scene phase.
    func updateSyncState(for scenePhase: ScenePhase) {
        // leave an initial sync running, do pause or restart it
        if case .initialSync = matrix.state { return }
        
        if scenePhase == .active {
            matrix.resumeSync()
        } else {
            matrix.pauseSync()
        }
    }
}
