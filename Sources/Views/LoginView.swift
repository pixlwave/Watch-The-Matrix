import SwiftUI
import Matrix

/// A view that displays text input for username, password and a custom homeserver
/// along with a button to log in.
struct LoginView: View {
    @EnvironmentObject var matrix: MatrixController
    
    @State var username = ""
    @State var password = ""
    @State var homeserverAddress = ""
    
    var body: some View {
        Form {
            TextField("Username", text: $username)
            SecureField("Password", text: $password)
            TextField("Homeserver", text: $homeserverAddress)   // this should be replaced by parsing the username
            Button("Login", action: login)
            .disabled(username.isEmpty || password.isEmpty)
        }
    }
    
    /// Parse the homeserver textfield and log in to matrix using
    /// the supplied username and password.
    func login() {
        if !homeserverAddress.isEmpty {
            if let homeserver = Homeserver(string: homeserverAddress) {
                matrix.client.homeserver = homeserver
            } else {
                return
            }
        }
        
        matrix.login(username: username, password: password)
    }
}

struct LoginView_Previews: PreviewProvider {
    static let matrix = MatrixController.preview
    
    static var previews: some View {
        LoginView()
            .environmentObject(matrix)
    }
}
