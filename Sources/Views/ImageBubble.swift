import SwiftUI

struct ImageBubble: View {
    @EnvironmentObject private var matrix: MatrixController
    let message: Message
    
    var body: some View {
        let url = matrix.client.mediaDownloadURL(fromMXC: message.mediaURL!)
        
        AsyncImage(url: url) { image in
            image
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } placeholder: {
            Rectangle()
                .foregroundColor(.gray)
                .aspectRatio(message.mediaAspectRadio ?? 1, contentMode: .fit)
        }
        .cornerRadius(6)
    }
}
