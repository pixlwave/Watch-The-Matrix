import SwiftUI
import Matrix
import CoreData

/// A view that shows the messages of a room.
struct RoomView: View {
    @EnvironmentObject var matrix: MatrixController
    @ObservedObject var room: Room
    @StateObject var viewModel: ViewModel
    
    /// A boolean indicating  whether `.onAppear` has been called.
    @State private var hasAppeared = false
    @State private var messageToReactTo: Message?
    
    var body: some View {
        // show the name of the message sender when there are more than 2 people in the room
        let showSenders = room.memberCount > 2
        
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if room.hasMoreMessages {
                        Button("Load More…") {
                            viewModel.loadMoreMessages()
                        }
                    }
                    
                    ForEach(viewModel.messages.indices, id: \.self) { index in
                        let message = viewModel.messages[index]
                        
                        // figure out whether the sender's name is the same to avoid duplicate labels
                        let previousMessage = viewModel.messages.indices.contains(index - 1) ? viewModel.messages[index - 1] : nil
                        let senderHasChanged = previousMessage?.sender != message.sender
                        
                        // hide the message if it has been redacted
                        if !message.isRedacted {
                            MessageView(message: message,
                                        showSender: showSenders ? senderHasChanged : false,
                                        bubbleColor: message.sender?.id == matrix.userID ? .accentColor : Color(.darkGray)
                            )
                            .onLongPressGesture { messageToReactTo = message }
                            .transition(.move(edge: .bottom))
                        } else {
                            Label("Deleted", systemImage: "trash")
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 6).foregroundColor(Color(.darkGray).opacity(1 / 3)))
                        }
                    }
                }
                .navigationTitle(room.name ?? room.generateName(for: matrix.userID))
                .onAppear {
                    if !hasAppeared {
                        // scroll to the last message and mark it as read
                        reader.scrollTo(viewModel.lastMessageID, anchor: .bottom)
                        viewModel.markRoomAsRead()
                        
                        // prevent the closure from running after the reaction sheet has been shown
                        hasAppeared = true
                    }
                }
                .onReceive(viewModel.$hasNewMessages) { newValue in
                    guard newValue else { return }
                    // scroll to the last message when there are new messages
                    #warning("This should additionally check whether the last message is on screen.")
                    withAnimation {
                        reader.scrollTo(viewModel.lastMessageID, anchor: .bottom)
                        // the view model will mark the room as read
                    }
                    
                    viewModel.hasNewMessages = false
                }
                .sheet(item: $messageToReactTo) { _ in
                    ReactionPicker(message: $messageToReactTo)
                }
            }
        }
    }
}

struct RoomView_Previews: PreviewProvider {
    static let matrix = MatrixController.preview

    static var previews: some View {
        NavigationView {
            let room = matrix.dataController.room(id: "!test0:example.org")!
            RoomView(room: room, viewModel: RoomView.ViewModel(room: room, matrix: matrix))
                .environmentObject(matrix)
                .environment(\.managedObjectContext, matrix.dataController.viewContext)
        }
    }
}
