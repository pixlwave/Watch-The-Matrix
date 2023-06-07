import SwiftUI
import Matrix
import Combine
import Observation

@Observable class LoginViewModel {
    private let matrix: MatrixController
    
    var username = ProcessInfo.processInfo.environment["username"] ?? ""
    var password = ProcessInfo.processInfo.environment["password"] ?? ""
    var homeserver: Homeserver? = ProcessInfo.processInfo.environment["homeserver"].flatMap(Homeserver.init)
    
    private var lookupCancellable: AnyCancellable? = nil
    
    var requiresManualHomeserverEntry = false
    var manualHomeserverString: String = ""
    
    /// A boolean indicating that login isn't possible yet.
    var hasIncompleteCredentials: Bool {
        username.isEmpty || password.isEmpty || homeserver == nil
    }
    
    private var loginCancellable: AnyCancellable? = nil
    var loginError: MatrixError? = nil
    
    init(matrix: MatrixController) {
        self.matrix = matrix
    }
    
    /// Parse the username and attempt to automatically set the homeserver.
    func parseUsername() {
        let usernameComponents = username.split(separator: ":")
        
        // assume logging into matrix.org
        if usernameComponents.count == 1 {
            withAnimation {
                if username.hasPrefix("@") { username = String(username.dropFirst()) }
                homeserver = .default
            }
            
            return
        }
        
        // at this stage there must be 2 components otherwise the username is invalid
        guard usernameComponents.count == 2 else { return }
        
        // prepend an @ if it was missed off
        if !username.hasPrefix("@") { username = "@\(username)"}
        
        // get the hostname and lookup it's homeserver
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
        guard let homeserver else { return }
        
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
