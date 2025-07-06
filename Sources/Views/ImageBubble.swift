import SwiftUI

struct ImageBubble: View {
    @Environment(MatrixController.self) private var matrix
    let message: Message
    
    enum ContentState { case loading, loaded(Image), error }
    @State private var state: ContentState = .loading
    
    var body: some View {
        content
            .cornerRadius(6)
            .task(id: message.id) {
                do {
                    try await loadImage()
                } catch {
                    state = .error
                }
            }
    }
    
    @ViewBuilder var content: some View {
        switch state {
        case .loading:
            placeholderBubble
                .overlay(ProgressView())
        case .loaded(let image):
            image
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        case .error:
            placeholderBubble
                .overlay {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.red)
                }
        }
    }
    
    var placeholderBubble: some View {
        Rectangle()
            .foregroundStyle(.tertiary)
            .aspectRatio(message.mediaAspectRadio ?? 1, contentMode: .fit)
    }
    
    func loadImage() async throws {
        // no need for initial state as the task should only run once
        guard case .loading = state else { return }
        
        let urlRequest = matrix.client.mediaDownloadURLRequest(fromMXC: message.mediaURL!)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let image = UIImage(data: data).map(Image.init) else {
            state = .error
            return
        }
        
        URLCache.shared.storeCachedResponse(CachedURLResponse(response: response, data: data), for: urlRequest)
        state = .loaded(image)
    }
}
