//
//  KCImageProvider.swift
//  KCImageCache
//
//  Created by 김규철 on 5/9/26.
//

import UIKit

/// `UIImageView` 에 1:1 부착되는 Provider.
@MainActor
final class KCImageProvider {

    private weak var imageView: UIImageView?
    private var task: Task<Void, Never>?
    private var currentDecoration: (any KCImagePlaceholder)?

    /// associated object key.
    nonisolated(unsafe) static let providerKey = malloc(1)!

    static func provider(for view: UIImageView) -> KCImageProvider {
        if let p = objc_getAssociatedObject(view, providerKey) as? KCImageProvider {
            return p
        }
        let p = KCImageProvider(view: view)
        objc_setAssociatedObject(view, providerKey, p, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return p
    }

    init(view: UIImageView) {
        self.imageView = view
    }

    deinit {
        task?.cancel()
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    func setImage(
        with request: ImageRequest?,
        placeholder: (any KCImagePlaceholder)?,
        failure: (any KCImagePlaceholder)?,
        pipeline: ImagePipeline
    ) {
        cancel()

        guard let imageView else { return }

        removeCurrentDecoration(from: imageView)

        if let placeholder {
            placeholder.add(to: imageView)
            currentDecoration = placeholder
        }

        guard let request else { return }

        task = Task { [weak self] in
            do {
                let image = try await pipeline.loadImage(request)
                guard !Task.isCancelled, let self, let imageView = self.imageView else { return }
                self.removeCurrentDecoration(from: imageView)
                imageView.image = image
            } catch is CancellationError {
                // 취소 시 placeholder 유지.
            } catch {
                guard let self, let imageView = self.imageView, let failure else { return }
                self.removeCurrentDecoration(from: imageView)
                failure.add(to: imageView)
                self.currentDecoration = failure
            }
        }
    }

    private func removeCurrentDecoration(from imageView: UIImageView) {
        currentDecoration?.remove(from: imageView)
        currentDecoration = nil
    }
}
