import SwiftUI

/// A view that displays a string inside a colored bubble with an optional footnote.
struct MessageBubble: View {
    let text: String
    var footnote: String? = nil
    let color: Color
    var alignment: HorizontalAlignment = .leading
    
    var body: some View {
        VStack(alignment: alignment) {
            Text(text)
            
            footnote.map {
                Text($0)
                    .font(.footnote)
                    .foregroundColor(.primary.opacity(0.6))
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .foregroundColor(color)
        )
    }
}

struct MessageBubble_Previews: PreviewProvider {
    static var previews: some View {
        MessageBubble(text: "Hello, World!", color: .accentColor)
        MessageBubble(text: "Hello, Universe!", footnote: "Edited", color: .accentColor)
    }
}
