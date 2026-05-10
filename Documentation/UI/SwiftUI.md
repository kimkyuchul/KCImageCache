# SwiftUI

`KCImage` View와 `KCImageLoader` ViewModel.

## KCImage

```swift
public struct KCImage<Content: View>: View {
    public init(
        request: ImageRequest?,
        pipeline: ImagePipeline = .shared,
        @ViewBuilder content: @escaping (KCImageState) -> Content
    )
}

public enum KCImageState {
    case loading        // request == nil 도 이 상태
    case success(Image)
    case failure(Error)
}
```

```swift
KCImage(request: ImageRequest(url: url)) { state in
    switch state {
    case .loading:           ProgressView()
    case .success(let img):  img.resizable().scaledToFit()
    case .failure:           Image(systemName: "photo")
    }
}
```

- `request` 변경 시 자동 재로드 (`.task(id:)`).
- View가 사라지면 자동 cancel.

## KCImageLoader

커스텀 View가 필요할 때 직접 사용.

```swift
@MainActor
public final class KCImageLoader: ObservableObject {
    @Published public private(set) var uiImage: UIImage?
    @Published public private(set) var isLoading: Bool
    @Published public private(set) var error: Error?
    public var image: Image? { /* uiImage → SwiftUI Image */ }

    public init(pipeline: ImagePipeline = .shared)
    public func load(_ request: ImageRequest?) async
}
```

```swift
@StateObject private var loader = KCImageLoader()

var body: some View {
    SomeCustomView(image: loader.image, isLoading: loader.isLoading)
        .task(id: request) { await loader.load(request) }
}
```

## See Also

- [UIKit](UIKit.md) · [ImagePipeline](../ImagePipeline/ImagePipeline.md)
