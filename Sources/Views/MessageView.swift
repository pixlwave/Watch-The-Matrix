import SwiftUI
import Matrix

struct MessageView: View {
    @ObservedObject var message: Message
    let showSender: Bool
    
    @Environment(\.managedObjectContext) var viewContext
    
    var body: some View {
        VStack(alignment: .leading) {
            let lastEdit = message.lastEdit
            Text(message.lastEdit?.body ?? message.body ?? "")
            
            if lastEdit != nil {
                Text("Edited")
                    .font(.footnote)
            }
            
            if showSender {
                Text(message.sender?.displayName ?? message.sender?.id ?? "")
                    .font(.footnote)
                    .foregroundColor(Color.primary.opacity(0.667))
            }
            
            if let reactions = try? viewContext.fetch(message.reactionsRequest), !reactions.isEmpty {
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
