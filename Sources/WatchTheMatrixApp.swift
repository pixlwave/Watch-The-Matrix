import SwiftUI
import Matrix

@main
struct WatchTheMatrixApp: App {
    @StateObject var matrix = Chat()
    
    var body: some Scene {
        WindowGroup {
            switch matrix.status {
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
