import SwiftUI

/// A view that displays a room's title and the last message in the room along with
/// an indication of whether the room has an unread messages.
struct RoomCell: View {
    @ObservedObject var room: Room
    @Environment(MatrixController.self) private var matrix
    
    var title: some View {
        HStack {
            // show a badge before the name if there are any unread messages
            if room.unreadCount > 0 {
                Image(systemName: "circlebadge.fill")
                    .imageScale(.small)
                    .foregroundColor(.accentColor)
            }
            
            Text(room.name ?? room.generateName(for: matrix.userID))
                .foregroundColor(.primary)
                .fontWeight(.medium)
                .lineLimit(1)
        }
    }
    
    @ViewBuilder var detail: some View {
        Text(room.excerpt ?? "")
            .lineLimit(1)
            .foregroundColor(.secondary)
        
        Text(room.lastMessageDate?.relativeString ?? "")
            .font(.footnote)
            .foregroundColor(.secondary)
    }
    
    @ViewBuilder var encryptionNotice: some View {
        (Text("Encrypted ") + Text(Image(systemName: "lock")))
            .lineLimit(1)
            .foregroundColor(.secondary)
        
        Text("Unsupported Room")
            .lineLimit(1)
            .font(.footnote)
            .foregroundColor(.secondary)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            title
            
            if room.isEncrypted {
                encryptionNotice
            } else {
                detail
            }
        }
    }
}

struct RoomCell_Previews: PreviewProvider {
    static let matrix = MatrixController.preview
    
    static var previews: some View {
        List {
            RoomCell(room: matrix.dataController.room(id: "!test0:example.org")!)
                .environment(matrix)
        }
    }
}
