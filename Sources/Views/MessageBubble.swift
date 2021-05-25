import SwiftUI

/// A view that displays a string inside a colored bubble.
struct MessageBubble: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .foregroundColor(color)
            )
    }
}
