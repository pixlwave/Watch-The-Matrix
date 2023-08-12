import SwiftUI

struct NotificationView: View {
    let message: String
    var body: some View {
        Text(message)
    }
}

struct NotifivationView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationView(message: "Hello, World!")
    }
}
