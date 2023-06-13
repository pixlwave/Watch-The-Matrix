import SwiftUI

struct NotificationView: View {
    let message: String
    var body: some View {
        Text(message)
    }
}

#Preview {
    NotificationView(message: "Hello, World!")
}
