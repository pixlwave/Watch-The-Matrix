import SwiftUI

/// A view that displays text input for username, password and a custom homeserver
/// along with a button to log in.
struct LoginView: View {
    @StateObject private var viewModel: ViewModel
    
    init(matrix: MatrixController) {
        let viewModel = ViewModel(matrix: matrix)
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    @ViewBuilder
    var homeserverFooter: some View {
        if !viewModel.requiresManualHomeserverEntry {
            viewModel.homeserver?.description.map { Text($0) }
        }
    }
    
    var body: some View {
        Form {
            Section(footer: homeserverFooter) {
                TextField("Username", text: $viewModel.username, onCommit: viewModel.parseUsername)
                    .textContentType(.username)
                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
            }
            
            if viewModel.requiresManualHomeserverEntry {
                Section {
                    TextField("Homeserver", text: $viewModel.manualHomeserverString, onCommit: viewModel.parseHomeserverAddress)
                        .textContentType(.URL)
                }
            }
            
            Button("Login", action: viewModel.login)
                .disabled(viewModel.hasIncompleteCredentials)
        }
        .navigationTitle("Login")
        .sheet(item: $viewModel.loginError) { loginError in
            Text(loginError.description)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static let matrix = MatrixController.preview
    
    static var previews: some View {
        LoginView(matrix: matrix)
    }
}
