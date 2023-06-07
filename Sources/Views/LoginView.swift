import SwiftUI

/// A view that displays text input for username, password and a custom homeserver
/// along with a button to log in.
struct LoginView: View {
    @Bindable private var viewModel: LoginViewModel
    
    init(matrix: MatrixController) {
        let viewModel = LoginViewModel(matrix: matrix)
        _viewModel = Bindable(wrappedValue: viewModel)
    }
    
    @ViewBuilder var homeserverFooter: some View {
        if !viewModel.requiresManualHomeserverEntry {
            viewModel.homeserver?.description.map { Text($0) }
        }
    }
    
    var body: some View {
        Form {
            Section(footer: homeserverFooter) {
                TextField("Username", text: $viewModel.username)
                    .textContentType(.username)
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.never)
                    .onSubmit(viewModel.parseUsername)
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

#Preview {
    NavigationStack {
        LoginView(matrix: MatrixController.preview)
    }
}
