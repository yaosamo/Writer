//
//  ImageTests.swift
//  iOSnothingTests
//

import XCTest
import CoreData
import ImageIO
import UniformTypeIdentifiers
@testable import Nothing

final class ImageTests: XCTestCase {

    private func makeImage(width: Int, height: Int, type: UTType = .png, gps: Bool = false) -> Data {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        // a gradient so it doesn't compress to nothing
        for x in stride(from: 0, to: width, by: max(1, width / 64)) {
            context.setFillColor(CGColor(red: CGFloat(x) / CGFloat(width), green: 0.4, blue: 0.6, alpha: 1))
            context.fill(CGRect(x: x, y: 0, width: max(1, width / 64), height: height))
        }
        let out = NSMutableData()
        let destination = CGImageDestinationCreateWithData(out, type.identifier as CFString, 1, nil)!
        var props: [CFString: Any] = [:]
        if gps { props[kCGImagePropertyGPSDictionary] = [kCGImagePropertyGPSLatitude: 52.5, kCGImagePropertyGPSLongitude: 13.4] }
        CGImageDestinationAddImage(destination, context.makeImage()!, props as CFDictionary)
        CGImageDestinationFinalize(destination)
        return out as Data
    }

    private func pixelSize(_ data: Data) -> (Int, Int) {
        let source = CGImageSourceCreateWithData(data as CFData, nil)!
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as! [CFString: Any]
        return (props[kCGImagePropertyPixelWidth] as! Int, props[kCGImagePropertyPixelHeight] as! Int)
    }

    func testSmallImageIsKeptAsIs() throws {
        let png = makeImage(width: 600, height: 400)
        let processed = try XCTUnwrap(ImageProcessing.process(png))
        XCTAssertEqual(processed.data, png, "Small PNGs (screenshots) are stored untouched")
        XCTAssertEqual(processed.width, 600)
        XCTAssertEqual(processed.height, 400)
    }

    func testLargeImageIsDownscaled() throws {
        let big = makeImage(width: 6000, height: 3000, type: .jpeg)
        let processed = try XCTUnwrap(ImageProcessing.process(big))
        XCTAssertEqual(processed.width, 2048)
        XCTAssertEqual(processed.height, 1024)
        let (pw, ph) = pixelSize(processed.data)
        XCTAssertEqual(max(pw, ph), 2048)
        let (vw, _) = pixelSize(processed.preview)
        XCTAssertEqual(vw, ImageProcessing.previewPixelSize)
        XCTAssertLessThan(processed.data.count, big.count)
    }

    func testLocationIsStripped() throws {
        let tagged = makeImage(width: 300, height: 200, type: .jpeg, gps: true)
        let processed = try XCTUnwrap(ImageProcessing.process(tagged))
        let source = CGImageSourceCreateWithData(processed.data as CFData, nil)!
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as! [CFString: Any]
        XCTAssertNil(props[kCGImagePropertyGPSDictionary])
    }

    func testNotAnImage() {
        XCTAssertNil(ImageProcessing.process(Data("hello".utf8)))
    }

    func testTokensRoundTrip() {
        let id = UUID()
        let text = "Before\n\(ImageToken.text(for: id))\nAfter"
        XCTAssertEqual(ImageToken.ids(in: text), [id])
        XCTAssertTrue(ImageToken.isTokenLine(ImageToken.text(for: id)))

        let attachment = ImageAttachment(imageID: id, pixelSize: CGSize(width: 800, height: 600))
        let shown = ImageText.attributed(text, attributes: [:]) { _ in attachment }
        XCTAssertEqual(shown.string, "Before\n\(ImageToken.attachmentCharacter)\nAfter")
        XCTAssertEqual(ImageText.plain(from: shown), text)
    }

    func testFitNeverUpscales() {
        let attachment = ImageAttachment(imageID: UUID(), pixelSize: CGSize(width: 400, height: 200))
        attachment.fit(maxWidth: 560)
        XCTAssertEqual(attachment.bounds.size, CGSize(width: 200, height: 100), "Natural size at 2x")
        attachment.fit(maxWidth: 120)
        XCTAssertEqual(attachment.bounds.size, CGSize(width: 120, height: 60))
    }

    func testTitleSkipsImageLines() {
        let context = PersistenceController(inMemory: true).container.viewContext
        let note = Item.create(in: context)
        note.note = "\(ImageToken.text(for: UUID()))\nTrip photos"
        XCTAssertEqual(note.displayTitle, "Trip photos")
    }

    @MainActor
    func testUnusedAttachmentsAreRemovedAndDeleteUndoRestoresThem() async throws {
        let context = PersistenceController(inMemory: true).container.viewContext
        let note = Item.create(in: context)
        let first = await Attachment.make(from: makeImage(width: 100, height: 100), for: note, in: context)
        let second = await Attachment.make(from: makeImage(width: 100, height: 100), for: note, in: context)
        let kept = try XCTUnwrap(first)
        XCTAssertNotNil(second)
        note.note = "photo:\n\(ImageToken.text(for: kept.id!))"
        note.removeUnusedAttachments(in: context)
        XCTAssertEqual(note.attachmentList.map(\.id), [kept.id])

        let undo = UndoManager()
        let noteID = note.id
        note.delete(in: context, undoManager: undo)
        undo.undo()
        let request = NSFetchRequest<Item>(entityName: "Item")
        request.predicate = NSPredicate(format: "id == %@", noteID! as CVarArg)
        let restored = try XCTUnwrap(try context.fetch(request).first)
        XCTAssertEqual(restored.attachmentList.count, 1)
        XCTAssertNotNil(restored.attachmentList.first?.data)
    }
}
