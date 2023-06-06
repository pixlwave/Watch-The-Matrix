import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var matrix: MatrixController
    @Environment(\.dismiss) private var dismiss
    
    @State private var isPresentingSignOutAlert = false
    
    var body: some View {
        Form {
            Section {
                Button(role: .destructive) {
                    isPresentingSignOutAlert = true
                } label: {
                    Text("Sign out")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Sign Out?", isPresented: $isPresentingSignOutAlert) {
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
        NavigationView {
            SettingsView()
                .environmentObject(matrix)
        }
        .previewDevice("Apple Watch Series 6 - 40mm")
    }
}
