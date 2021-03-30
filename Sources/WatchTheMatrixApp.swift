import SwiftUI
import Matrix

@main
struct WatchTheMatrixApp: App {
    @StateObject var matrix = MatrixController()
    
    var body: some Scene {
        WindowGroup {
            switch matrix.state {
            case .signedOut:
                LoginView()
                    .environmentObject(matrix)
            case .syncing:
                ProgressView()
            case .idle:
                NavigationView {
                    RootView()
                        .environment(\.managedObjectContext, matrix.dataController.viewContext)
                        .environmentObject(matrix)
                }
            case .syncError(let error):
                Text("Error syncing messages: \(error.description)")
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }

        WKNotificationScene(controller: NotificationController.self, category: "myCategory")
    }
}
