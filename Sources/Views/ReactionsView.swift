import SwiftUI

/// A view that displays a horizontally scrolling list of grouped reactions
struct ReactionsView: View {
    let reactions: [(key: String, count: Int)]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(0..<reactions.count, id: \.self) { index in
                    HStack {
                        Text(reactions[index].key)
                        Text(String(reactions[index].count))
                            .font(.footnote)
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .background(Capsule().foregroundColor(Color(.darkGray)))
                    .accessibilityElement(children: .combine);      #warning("This accessibility element isn't surfaced.")
                }
            }
        }
    }
}
