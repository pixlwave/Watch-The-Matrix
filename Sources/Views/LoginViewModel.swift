import SwiftUI
import Matrix
import Combine

extension LoginView {
    class ViewModel: ObservableObject {
        private var matrix: MatrixController
        
        @Published var username = ""
        @Published var password = ""
        @Published var homeserver: Homeserver?
        
        private var lookupCancellable: AnyCancellable?
        
        @Published var requiresManualHomeserverEntry = false
        @Published var manualHomeserverString: String = ""
        
        /// A boolean indicating that login isn't possible yet.
        var hasIncompleteCredentials: Bool {
            username.isEmpty || password.isEmpty || homeserver == nil
        }
        
        private var loginCancellable: AnyCancellable?
        @Published var loginError: MatrixError?
        
        init(matrix: MatrixController) {
            self.matrix = matrix
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
                    if case .failure = completion { self.manualHomeserverEntry() }
                } receiveValue: { url in
                    self.lookupSuccess(url: url)
                }
        }
        
        /// Clears the homeserver value and displays the homeserver text field.
        func manualHomeserverEntry() {
            withAnimation {
                self.homeserver = nil
                self.requiresManualHomeserverEntry = true
            }
        }
        
        /// Ensures a valid homeserver can be initialised and sets the homeserver if true, otherwise enables manual homeserver entry.
        func lookupSuccess(url: URL) {
            withAnimation {
                guard let homeserver = Homeserver(url: url) else { manualHomeserverEntry(); return }
                
                self.homeserver = homeserver
                self.requiresManualHomeserverEntry = false
            }
        }
        
        /// Parses the custom homeserver string and uses it if valid.
        func parseHomeserverAddress() {
            guard
                !manualHomeserverString.isEmpty,
                let homeserver = Homeserver(string: manualHomeserverString)
            else { return }
                    
            self.homeserver = homeserver
        }
        
        /// Log in to the homeserver using the supplied username and password.
        /// This method will return immediately if a homeserver has not been set.
        func login() {
            guard let homeserver = homeserver else { return }
            
            matrix.client.homeserver = homeserver
            
            loginCancellable = matrix.login(username: username, password: password)
                .receive(on: DispatchQueue.main)
                .sink { completion in
                    if case let .failure(error) = completion {
                        self.loginError = error
                    }
                } receiveValue: { _ in }

        }
    }
}
