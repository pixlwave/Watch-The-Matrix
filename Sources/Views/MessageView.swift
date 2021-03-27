import SwiftUI
import Matrix

struct MessageView: View {
    @ObservedObject var message: Message
    let showSender: Bool
    
    var body: some View {
        let lastEdit = message.lastEdit
        let reactions = message.reactionsViewModel
        
        VStack(alignment: .leading) {
            Text(lastEdit?.body ?? message.body ?? "")
            
            if lastEdit != nil {
                Text("Edited")
                    .font(.footnote)
            }
            
            if showSender {
                Text(message.sender?.displayName ?? message.sender?.id ?? "")
                    .font(.footnote)
                    .foregroundColor(Color.primary.opacity(0.667))
            }
            
            if !reactions.isEmpty {
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
                            .background(Capsule().foregroundColor(.black))
                        }
                    }
                }
            }
        }
        .id(message.id)
    }
}
