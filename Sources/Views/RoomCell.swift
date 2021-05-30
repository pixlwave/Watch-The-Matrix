import SwiftUI

/// A view that displays a room's title and the last message in the room along with
/// an indication of whether the room has an unread messages.
struct RoomCell: View {
    @ObservedObject var room: Room
    @EnvironmentObject var matrix: MatrixController
    
    var title: some View {
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
    }
    
    @ViewBuilder var detail: some View {
        let lastMessage = room.lastMessage
        
        Text(lastMessage?.lastEdit?.body ?? lastMessage?.body ?? "")
            .lineLimit(1)
            .foregroundColor(.secondary)
        
        Text(lastMessage?.date?.relativeString ?? "")
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
                .environmentObject(matrix)
        }
    }
}
