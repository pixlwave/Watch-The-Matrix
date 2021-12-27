import SwiftUI

/// A view that will lay out its content appropriately depending on whether it
/// represents a message from the current user or someone else.
struct MessageAligner<Content: View>: View {
    let isCurrentUser: Bool
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer()
            }
            
            content()
            
            if !isCurrentUser {
                Spacer()
            }
        }
        .padding(isCurrentUser ? .leading : .trailing, 18)
    }
}
