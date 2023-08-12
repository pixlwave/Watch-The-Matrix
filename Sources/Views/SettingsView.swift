import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var matrix: MatrixController
    @Environment(\.dismiss) private var dismiss
    
    @State private var isPresentingSignOutConfirmation = false
    
    var body: some View {
        Form {
            Section {
                Button(role: .destructive) {
                    isPresentingSignOutConfirmation = true
                } label: {
                    Text("Sign out")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Sign Out?", isPresented: $isPresentingSignOutConfirmation) {
            Button("Sign out", role: .destructive) {
                matrix.logout()
                dismiss()
            }
            
            Button("Cancel") { }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static let matrix = MatrixController.preview
    
    static var previews: some View {
        NavigationStack {
            SettingsView()
                .environmentObject(matrix)
        }
    }
}
