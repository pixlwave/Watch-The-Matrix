import SwiftUI
import Matrix
import Combine

/// A view that displays text input for username, password and a custom homeserver
/// along with a button to log in.
struct LoginView: View {
    @EnvironmentObject var matrix: MatrixController
    
    @State private var username = ""
    @State private var password = ""
    @State private var homeserver: Homeserver?
    
    @State private var lookupCancellable: AnyCancellable?
    
    @State private var homeserverFieldIsHidden = true
    @State private var homeserverAddress: String = ""
    
    @ViewBuilder
    var homeserverFooter: some View {
        if homeserverFieldIsHidden {
            homeserver?.description.map { Text($0) }
        }
    }
    
    var body: some View {
        Form {
            Section(footer: homeserverFooter) {
                TextField("Username", text: $username, onCommit: parseUsername)
                    .textContentType(.username)
                SecureField("Password", text: $password)
                    .textContentType(.password)
            }
            
            if !homeserverFieldIsHidden {
                Section {
                    TextField("Homeserver", text: $homeserverAddress, onCommit: parseHomeserverAddress)
                        .textContentType(.URL)
                }
            }
            
            Button("Login", action: login)
                .disabled(username.isEmpty || password.isEmpty || homeserver == nil)
        }
        .navigationTitle("Login")
    }
    
    /// Log in to the homeserver using the supplied username and password.
    /// This method will return immediately if a homeserver has not been set.
    func login() {
        guard let homeserver = homeserver else { return }
        
        matrix.client.homeserver = homeserver
        matrix.login(username: username, password: password)
    }
    
    /// Parse the username for a hostname and lookup the .well-known if one is found.
    func parseUsername() {
        let usernameComponents = username.split(separator: ":")
        
        if usernameComponents.count == 1 {          // assume logging into matrix.org
            withAnimation {
                if username.hasPrefix("@") { username = String(username.dropFirst()) }
                homeserver = .default
            }
            
            return
        } else if usernameComponents.count > 2 {    // invalid username entered
            return
        }
        
        if !username.hasPrefix("@") { username = "@\(username)"}
        
        let host = String(usernameComponents[1])
        
        lookupCancellable = matrix.client.lookupHomeserver(for: host)
            .receive(on: DispatchQueue.main)
            .map(\.homeserver.baseURL)
            .sink { completion in
                if case .failure = completion { manualHomeserverEntry() }
            } receiveValue: { url in
                lookupSuccess(url: url)
            }
    }
    
    /// Clears the homeserver value and displays the homeserver text field.
    func manualHomeserverEntry() {
        withAnimation {
            self.homeserver = nil
            self.homeserverFieldIsHidden = false
        }
    }
    
    /// Ensures a valid homeserver can be initialised and sets the homeserver if true, otherwise enables manual homeserver entry.
    func lookupSuccess(url: URL) {
        withAnimation {
            guard let homeserver = Homeserver(url: url) else { manualHomeserverEntry(); return }
            
            self.homeserver = homeserver
            self.homeserverFieldIsHidden = true
        }
    }
    
    /// Parses the custom homeserver string and uses it if valid.
    func parseHomeserverAddress() {
        guard
            !homeserverAddress.isEmpty,
            let homeserver = Homeserver(string: homeserverAddress)
        else { return }
                
        self.homeserver = homeserver
    }
}

struct LoginView_Previews: PreviewProvider {
    static let matrix = MatrixController.preview
    
    static var previews: some View {
        LoginView()
            .environmentObject(matrix)
    }
}
