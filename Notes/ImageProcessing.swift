//
//  ImageProcessing.swift
//  Notes
//
//  Prepares pasted images for storage and sync (ImageIO, shared by macOS and iOS).
//  Small images are kept byte-for-byte; large ones are downscaled and re-encoded.
//  Location metadata never leaves the device.
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageProcessing {

    // Longest side of the stored image, and of the preview copy the editor shows
    static let maxPixelSize = 2048
    static let previewPixelSize = 1200
    // Images at or under these limits are stored untouched (screenshots stay pixel-perfect)
    static let keepAsIsBytes = 1_500_000
    static let keepAsIsTypes: Set<String> = [UTType.png.identifier, UTType.jpeg.identifier, UTType.heic.identifier]

    struct Processed {
        let data: Data
        let preview: Data
        let width: Int      // pixels, after orientation
        let height: Int
    }

    static func process(_ input: Data) -> Processed? {
        guard let source = CGImageSourceCreateWithData(input as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let rawWidth = props[kCGImagePropertyPixelWidth] as? Int,
              let rawHeight = props[kCGImagePropertyPixelHeight] as? Int, rawWidth > 0, rawHeight > 0 else { return nil }

        let orientation = props[kCGImagePropertyOrientation] as? Int ?? 1
        let longest = max(rawWidth, rawHeight)
        let type = CGImageSourceGetType(source) as String? ?? ""
        let hasGPS = props[kCGImagePropertyGPSDictionary] != nil
        let hasAlpha = props[kCGImagePropertyHasAlpha] as? Bool ?? false

        let data: Data
        let width: Int, height: Int
        if longest <= maxPixelSize, input.count <= keepAsIsBytes, keepAsIsTypes.contains(type), orientation == 1, !hasGPS {
            data = input
            (width, height) = (rawWidth, rawHeight)
        } else {
            guard let image = downscaled(source, maxPixel: min(longest, maxPixelSize)),
                  let encoded = encode(image, hasAlpha: hasAlpha, quality: 0.8) else { return nil }
            data = encoded
            (width, height) = (image.width, image.height)
        }

        guard let previewSource = CGImageSourceCreateWithData(data as CFData, nil),
              let previewImage = downscaled(previewSource, maxPixel: min(max(width, height), previewPixelSize)),
              let preview = encode(previewImage, hasAlpha: hasAlpha, quality: 0.7) else { return nil }
        return Processed(data: data, preview: preview, width: width, height: height)
    }

    // Memory-friendly decode at a target size, with EXIF orientation applied
    static func downscaled(_ source: CGImageSource, maxPixel: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
    }

    // HEIC when the system can encode it, otherwise PNG (transparency) or JPEG. No metadata is copied
    static func encode(_ image: CGImage, hasAlpha: Bool, quality: Double) -> Data? {
        let candidates: [UTType] = hasAlpha ? [.heic, .png] : [.heic, .jpeg]
        for type in candidates {
            let out = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(out, type.identifier as CFString, 1, nil) else { continue }
            let options: [CFString: Any] = type == .png ? [:] : [kCGImageDestinationLossyCompressionQuality: quality]
            CGImageDestinationAddImage(destination, image, options as CFDictionary)
            if CGImageDestinationFinalize(destination), out.length > 0 {
                return out as Data
            }
        }
        return nil
    }
}

// Images live in the note text as one token per image, on its own line
enum ImageToken {
    static let attachmentCharacter = "\u{FFFC}"

    static func text(for id: UUID) -> String {
        "![image](nothing:\(id.uuidString))"
    }

    private static let regex = try! NSRegularExpression(pattern: #"!\[image\]\(nothing:([0-9A-Fa-f-]{36})\)"#)

    // Every token in `text` with its range and image id
    static func tokens(in text: String) -> [(range: NSRange, id: UUID)] {
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            UUID(uuidString: ns.substring(with: match.range(at: 1))).map { (match.range, $0) }
        }
    }

    static func ids(in text: String) -> Set<UUID> {
        Set(tokens(in: text).map(\.id))
    }

    static func isTokenLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let match = tokens(in: trimmed).first else { return false }
        return match.range.location == 0 && match.range.length == (trimmed as NSString).length
    }
}
