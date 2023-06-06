import SwiftUI

/// A horizontal `ScrollView` that will pad the start of it's content
/// when the alignment is set to `.trailing`.
struct AlignedScrollView<Content: View>: View {
    let alignment: HorizontalAlignment
    var showsIndicators: Bool = true
    
    @ViewBuilder let content: () -> Content
    
    @State private var contentWidth: CGFloat = .zero
    @State private var width: CGFloat = .zero
    
    private var leadingWidth: CGFloat {
        guard alignment == .trailing else { return 0 }
        return max(0, width - contentWidth)
    }
    
    private var contentReader: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(key: SizeKey.self, value: geometry.size)
        }
        .onPreferenceChange(SizeKey.self) { contentWidth = $0.width }
    }
    
    private var frameReader: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(key: SizeKey.self, value: geometry.size)
        }
        .onPreferenceChange(SizeKey.self) { width = $0.width }
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: showsIndicators) {
            HStack {
                Spacer()
                    .frame(width: leadingWidth)
                
                content()
                    .background { contentReader }
            }
        }
        .background { frameReader }
    }
    
}

struct SizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
