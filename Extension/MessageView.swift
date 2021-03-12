import SwiftUI
import Matrix

struct MessageView: View {
    @ObservedObject var message: Message
    let showSender: Bool
    
    @Environment(\.managedObjectContext) var managedObjectContext
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(message.body ?? "")
            
            if showSender {
                Text(message.sender?.displayName ?? message.sender?.id ?? "")
                    .font(.footnote)
                    .foregroundColor(Color.primary.opacity(0.667))
            }
            
            if let reactions = try? managedObjectContext.fetch(message.reactionsRequest), !reactions.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 25))]) {
                    ForEach(reactions) { reaction in
                        Text(reaction.key ?? "")
                    }
                }
            }
        }
        .id(message.id)
    }
}
