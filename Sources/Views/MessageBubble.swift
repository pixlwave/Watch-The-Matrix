import SwiftUI

/// A view that displays a string inside a colored bubble with an optional footnote.
struct MessageBubble: View {
    let text: String
    var footnote: String? = nil
    let color: Color
    var isReply: Bool = false
    var alignment: HorizontalAlignment = .leading
    
    var bubbleShape: some InsettableShape {
        RoundedRectangle(cornerRadius: 6)
    }
    
    var body: some View {
        VStack(alignment: alignment) {
            Text(text)
                .font(isReply ? .footnote : .body)
                .lineLimit(isReply ? 3 : nil)
                .foregroundStyle(isReply ? color : .primary)
            
            footnote.map {
                Text($0)
                    .font(.footnote)
                    .foregroundColor(.primary.opacity(0.6))
            }
        }
        .padding(4)
        .background(
            bubbleShape
                .strokeBorder(isReply ? color : .clear)
                .background(isReply ? .clear : color, in: bubbleShape)
        )
    }
}

struct MessageBubble_Previews: PreviewProvider {
    static var previews: some View {
        MessageBubble(text: "Hello, World!", color: .accentColor)
        MessageBubble(text: "Hello, Universe!", footnote: "Edited", color: .accentColor)
        MessageBubble(text: "Thank you", color: .secondary.opacity(0.667), isReply: true)
    }
}
