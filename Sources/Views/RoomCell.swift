import SwiftUI

/// A view that displays a room's title and the last message in the room along with
/// an indication of whether the room has an unread messages.
struct RoomCell: View {
    @ObservedObject var room: Room
    @EnvironmentObject var matrix: MatrixController
    
    /// The body of the last message, taking into account any edits. This will return
    /// an empty string if there isn't a valid body to return.
    var lastMessageBody: String {
        guard let lastMessage = room.lastMessage else { return "" }
        return lastMessage.lastEdit?.body ?? lastMessage.body ?? ""
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                // show a badge before the name if there are any unread messages
                if room.unreadCount > 0 {
                    Image(systemName: "circlebadge.fill")
                        .imageScale(.small)
                        .foregroundColor(.accentColor)
                }
                
                Text(room.name ?? room.generateName(for: matrix.userID))
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            
            Text(lastMessageBody)
                .lineLimit(1)
                .foregroundColor(.secondary)
            
            Text(room.lastMessage?.date?.relativeString ?? "")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
}


struct RoomCell_Previews: PreviewProvider {
    static let matrix = MatrixController.preview
    
    static var previews: some View {
        List {
            RoomCell(room: matrix.dataController.room(id: "!test0:example.org")!)
                .environmentObject(matrix)
        }
    }
}
