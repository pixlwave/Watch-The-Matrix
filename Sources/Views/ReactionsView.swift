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
                    .background(
                        Capsule()
                            .strokeBorder(reaction.isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
                            .background(reaction.isSelected ? Color.accentColor.opacity(0.5) : Color(.darkGray), in: Capsule())
                    )
                    .accessibilityElement(children: .combine);      #warning("This accessibility element isn't surfaced.")
                }
            }
        }
    }
}

struct Previews_ReactionsView_Previews: PreviewProvider {
    static var previews: some View {
        ReactionsView(reactions: [
            AggregatedReaction(key: "👍", count: 3, isSelected: false),
            AggregatedReaction(key: "😄", count: 2, isSelected: true),
            AggregatedReaction(key: "🟩", count: 10, isSelected: false),
            AggregatedReaction(key: "🟨", count: 1, isSelected: true)
        ], alignment: .leading)
    }
}
