import SwiftUI
import Matrix

@main
struct WatchTheMatrixApp: App {
    @WKApplicationDelegateAdaptor var delegate: ExtensionDelegate
    
    @StateObject var matrix = MatrixController()
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            // navigation view prevents overlap with the time when scrolling the login form
            // doesn't have any effect on the progress view's layout so use it all the time
            NavigationView {
                switch matrix.state {
                case .signedOut:
                    LoginView(matrix: matrix)
                case .initialSync:
                    ProgressView()
                case .syncing, .syncError:
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
        // leave an initial sync running, don't pause or restart it
        if case .initialSync = matrix.state { return }
        
        if scenePhase == .active {
            matrix.resumeSync()
        } else {
            matrix.pauseSync()
        }
    }
}
