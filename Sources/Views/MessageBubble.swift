import SwiftUI

/// A view that displays a string inside a colored bubble with an optional footnote.
struct MessageBubble: View {
    let text: String
    let footnote: String?
    let color: Color
    
    init(text: String, footnote: String? = nil, color: Color) {
        self.text = text
        self.footnote = footnote
        self.color = color
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(text)
            
            footnote.map {
                Text($0)
                    .font(.footnote)
                    .foregroundColor(.secondary)
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
