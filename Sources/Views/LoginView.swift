import SwiftUI
import Matrix

struct LoginView: View {
    @EnvironmentObject var matrix: MatrixController
    
    @State var username = ""
    @State var password = ""
    @State var homeserverAddress = ""
    
    var body: some View {
        Form {
            TextField("Username", text: $username)
            SecureField("Password", text: $password)
            TextField("Homeserver", text: $homeserverAddress)
            Button("Login", action: login)
            .disabled(username.isEmpty || password.isEmpty)
        }
    }
    
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
