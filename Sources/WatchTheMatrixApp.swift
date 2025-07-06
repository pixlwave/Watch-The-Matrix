import SwiftUI
import Matrix

@main
struct WatchTheMatrixApp: App {
    @State private var matrix = MatrixController()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            // navigation view prevents overlap with the time when scrolling the login form
            // doesn't have any effect on the progress view's layout so use it all the time
            NavigationStack {
                switch matrix.state {
                case .signedOut:
                    LoginView(matrix: matrix)
                case .initialSync, .signingOut:
                    ProgressView()
                case .syncing, .syncError:
                    RootView()
                        .environment(\.managedObjectContext, matrix.dataController.viewContext)
                        .environment(matrix)
                }
            }
        }
        .onChange(of: scenePhase, updateSyncState)

        WKNotificationScene(controller: NotificationController.self, category: "myCategory")
    }
    
    /// Pauses or resumes syncing appropriately for the supplied scene phase.
    func updateSyncState(from oldPhase: ScenePhase, to scenePhase: ScenePhase) {
        // leave an initial sync running, don't pause or restart it
        if case .initialSync = matrix.state { return }
        
        if scenePhase == .active {
            matrix.resumeSync()
        } else {
            matrix.pauseSync()
        }
    }
}
