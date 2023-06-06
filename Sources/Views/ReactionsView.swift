import SwiftUI

/// A view that displays a horizontally scrolling list of grouped reactions
struct ReactionsView: View {
    let reactions: [AggregatedReaction]
    let alignment: HorizontalAlignment
    
    var body: some View {
        AlignedScrollView(alignment: alignment, showsIndicators: false) {
            HStack {
                ForEach(reactions, id: \.key) { reaction in
                    HStack {
                        Text(reaction.key)
                        Text(String(reaction.count))
                            .font(.footnote)
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .background {
                        Capsule()
                            .strokeBorder(reaction.eventIDToRedact == nil ? .clear : Color.accentColor, lineWidth: 1.5)
                            .background(reaction.eventIDToRedact == nil ? Color(.darkGray) : Color.accentColor.opacity(0.5), in: Capsule())
                    }
                    .accessibilityElement(children: .combine);      #warning("This accessibility element isn't surfaced.")
                }
            }
        }
    }
}

#Preview {
    ReactionsView(reactions: [
        AggregatedReaction(key: "👍", count: 3, eventIDToRedact: nil),
        AggregatedReaction(key: "😄", count: 2, eventIDToRedact: "smile"),
        AggregatedReaction(key: "🟩", count: 10, eventIDToRedact: nil),
        AggregatedReaction(key: "🟨", count: 1, eventIDToRedact: "yellow")
    ], alignment: .leading)
}
