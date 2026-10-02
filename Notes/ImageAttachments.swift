//
//  ImageAttachments.swift
//  Notes
//
//  Images in notes (Pro): storage in Core Data, display as text attachments, and the
//  conversion between the stored plain text (with image tokens) and what the editor shows.
//

import CoreData
import SwiftUI
#if canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

// MARK: - Storage

extension Attachment {
    static func fetch(_ id: UUID, in context: NSManagedObjectContext) -> Attachment? {
        let request = NSFetchRequest<Attachment>(entityName: "Attachment")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    // Processes off the main thread, then stores the image with the note
    @MainActor
    static func make(from data: Data, for note: Item, in context: NSManagedObjectContext) async -> Attachment? {
        guard let processed = await Task.detached(priority: .userInitiated, operation: { ImageProcessing.process(data) }).value else {
            return nil
        }
        let attachment = Attachment(context: context)
        attachment.id = UUID()
        attachment.date = Date()
        attachment.data = processed.data
        attachment.preview = processed.preview
        attachment.width = Int32(processed.width)
        attachment.height = Int32(processed.height)
        attachment.note = note
        context.saveIfNeeded()
        return attachment
    }

    // Everything needed to recreate the attachment (undoing a note delete)
    struct Snapshot {
        let id: UUID?, date: Date?, data: Data?, preview: Data?, width: Int32, height: Int32
    }
    var snapshot: Snapshot { Snapshot(id: id, date: date, data: data, preview: preview, width: width, height: height) }

    @discardableResult
    static func restore(_ snapshot: Snapshot, for note: Item, in context: NSManagedObjectContext) -> Attachment {
        let attachment = Attachment(context: context)
        attachment.id = snapshot.id
        attachment.date = snapshot.date
        attachment.data = snapshot.data
        attachment.preview = snapshot.preview
        attachment.width = snapshot.width
        attachment.height = snapshot.height
        attachment.note = note
        return attachment
    }
}

extension Item {
    var attachmentList: [Attachment] {
        ((attachments as? Set<Attachment>) ?? []).filter { !$0.isDeleted }
    }

    // Images whose token was removed from the text. Run when leaving the note, so undo
    // inside the editor can still bring an image back
    func removeUnusedAttachments(in context: NSManagedObjectContext) {
        let used = ImageToken.ids(in: noteText)
        let unused = attachmentList.filter { !($0.id.map(used.contains) ?? false) }
        guard !unused.isEmpty else { return }
        unused.forEach(context.delete)
        context.saveIfNeeded()
    }
}

// MARK: - Text attachment

final class ImageAttachment: NSTextAttachment {
    let imageID: UUID
    private(set) var pixelSize: CGSize

    init(imageID: UUID, pixelSize: CGSize) {
        self.imageID = imageID
        self.pixelSize = pixelSize
        super.init(data: nil, ofType: nil)
    }

    required init?(coder: NSCoder) { nil }

    func update(pixelSize: CGSize) {
        self.pixelSize = pixelSize
    }

    // Fit the text width, never larger than the image's natural size (2x pixels per point)
    func fit(maxWidth: CGFloat) {
        let ratio = pixelSize.width > 0 ? pixelSize.height / pixelSize.width : 0.75
        let natural = pixelSize.width > 0 ? pixelSize.width / 2 : maxWidth
        let width = max(40, min(maxWidth, natural))
        bounds = CGRect(x: 0, y: 0, width: width, height: (width * ratio).rounded())
    }
}

// MARK: - Plain text <-> attributed text

enum ImageText {
    // Stored text (tokens) to what the editor shows (attachments)
    static func attributed(_ text: String, attributes: [NSAttributedString.Key: Any],
                           attachment: (UUID) -> ImageAttachment) -> NSMutableAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: attributes)
        for token in ImageToken.tokens(in: text).reversed() {
            let image = NSMutableAttributedString(attachment: attachment(token.id))
            image.addAttributes(attributes, range: NSRange(location: 0, length: image.length))
            result.replaceCharacters(in: token.range, with: image)
        }
        return result
    }

    // What the editor shows back to stored text
    static func plain(from text: NSAttributedString) -> String {
        let result = NSMutableString(string: text.string)
        var replacements: [(NSRange, String)] = []
        text.enumerateAttribute(.attachment, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            if let image = value as? ImageAttachment {
                replacements.append((range, ImageToken.text(for: image.imageID)))
            }
        }
        for (range, token) in replacements.reversed() {
            result.replaceCharacters(in: range, with: token)
        }
        return result as String
    }
}

// MARK: - Loading and display

@MainActor
final class ImageAttachmentController {
    let item: Item
    let context: NSManagedObjectContext
    var maxWidth: CGFloat = 560
    var placeholderColor: CGColor
    // Called when an attachment's image or size changed, so the editor can redraw it
    var onChange: ((ImageAttachment) -> Void)?

    private var attachments: [UUID: ImageAttachment] = [:]
    private var missing: Set<UUID> = []
    private var observer: NSObjectProtocol?
    private static let cache: NSCache<NSUUID, PlatformImage> = {
        let cache = NSCache<NSUUID, PlatformImage>()
        cache.countLimit = 80
        return cache
    }()

    init(item: Item, context: NSManagedObjectContext, placeholderColor: CGColor) {
        self.item = item
        self.context = context
        self.placeholderColor = placeholderColor
        // Images can arrive from iCloud after the note's text: fill them in when they do
        observer = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextObjectsDidChange, object: context, queue: .main) { [weak self] note in
            let inserted = (note.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject>) ?? []
            let refreshed = (note.userInfo?[NSRefreshedObjectsKey] as? Set<NSManagedObject>) ?? []
            let ids = (inserted.union(refreshed)).compactMap { ($0 as? Attachment)?.id }
            MainActor.assumeIsolated {
                self?.resolve(Set(ids))
            }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func attachment(for id: UUID) -> ImageAttachment {
        if let existing = attachments[id] { return existing }
        let stored = Attachment.fetch(id, in: context)
        let size = stored.map { CGSize(width: Int($0.width), height: Int($0.height)) } ?? CGSize(width: 4, height: 3)
        let attachment = ImageAttachment(imageID: id, pixelSize: size)
        attachment.fit(maxWidth: maxWidth)
        attachment.image = Self.cache.object(forKey: id as NSUUID) ?? placeholder(for: size)
        attachments[id] = attachment
        if let stored {
            load(stored, into: attachment)
        } else {
            missing.insert(id)
        }
        return attachment
    }

    // Window or text width changed
    func refit(maxWidth: CGFloat) {
        guard abs(maxWidth - self.maxWidth) > 0.5 else { return }
        self.maxWidth = maxWidth
        for attachment in attachments.values {
            attachment.fit(maxWidth: maxWidth)
            onChange?(attachment)
        }
    }

    // Stores a pasted image; nil when it couldn't be read
    func add(_ data: Data) async -> UUID? {
        guard let stored = await Attachment.make(from: data, for: item, in: context), let id = stored.id else { return nil }
        return id
    }

    func fullImage(for id: UUID) async -> CGImage? {
        guard let data = Attachment.fetch(id, in: context)?.data else { return nil }
        return await Task.detached(priority: .userInitiated) { ImageProcessing.decode(data) }.value
    }

    private func resolve(_ ids: Set<UUID>) {
        for id in ids.intersection(missing) {
            guard let attachment = attachments[id], let stored = Attachment.fetch(id, in: context) else { continue }
            missing.remove(id)
            attachment.update(pixelSize: CGSize(width: Int(stored.width), height: Int(stored.height)))
            attachment.fit(maxWidth: maxWidth)
            onChange?(attachment)
            load(stored, into: attachment)
        }
    }

    // Decodes the preview copy in the background (rounded corners baked in), then caches it
    private func load(_ stored: Attachment, into attachment: ImageAttachment) {
        let key = attachment.imageID as NSUUID
        if let cached = Self.cache.object(forKey: key) {
            attachment.image = cached
            return
        }
        guard let preview = stored.preview ?? stored.data else { return }
        Task { [weak self] in
            let cgImage = await Task.detached(priority: .utility) { () -> CGImage? in
                guard let source = CGImageSourceCreateWithData(preview as CFData, nil),
                      let image = ImageProcessing.downscaled(source, maxPixel: ImageProcessing.previewPixelSize) else { return nil }
                return Self.rounded(image)
            }.value
            guard let cgImage, let self else { return }
            let image = Self.platformImage(cgImage)
            Self.cache.setObject(image, forKey: key)
            attachment.image = image
            self.onChange?(attachment)
        }
    }

    private func placeholder(for size: CGSize) -> PlatformImage {
        let width = 64, height = max(8, Int(64 * size.height / max(size.width, 1)))
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let path = CGPath(roundedRect: CGRect(x: 0, y: 0, width: width, height: height), cornerWidth: 3, cornerHeight: 3, transform: nil)
        context.addPath(path)
        context.setFillColor(placeholderColor)
        context.fillPath()
        return Self.platformImage(context.makeImage()!)
    }

    nonisolated private static func rounded(_ image: CGImage) -> CGImage? {
        let width = image.width, height = image.height
        let radius = CGFloat(max(width, height)) * 0.018
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.clip()
        context.draw(image, in: rect)
        return context.makeImage()
    }

    private static func platformImage(_ cgImage: CGImage) -> PlatformImage {
        #if canImport(AppKit)
        NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        #else
        UIImage(cgImage: cgImage)
        #endif
    }
}

// MARK: - Full-size preview

struct ImagePreview: View {
    let id: UUID
    let controller: ImageAttachmentController
    let close: () -> Void

    @State private var image: CGImage?
    @State private var zoom: CGFloat = 1

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            if let image {
                Image(decorative: image, scale: 2)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(zoom)
                    .padding(32)
                    .gesture(MagnifyGesture().onChanged { zoom = max(1, $0.magnification) }.onEnded { _ in
                        withAnimation(.smooth) { zoom = 1 }
                    })
            } else {
                ProgressView()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: close)
        .accessibilityAddTraits(.isImage)
        .accessibilityLabel("Image")
        .task {
            image = await controller.fullImage(for: id)
        }
        #if os(macOS)
        .onExitCommand(perform: close)
        #endif
    }
}
