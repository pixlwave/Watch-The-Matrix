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
    
    func updateSyncState(for scenePhase: ScenePhase) {
        if scenePhase == .active {
            if case .initialSync = matrix.state {
            } else {
                matrix.resumeSync()
            }
        } else {
            if case .syncing = matrix.state {
                matrix.pauseSync()
            }
        }
    }
}
