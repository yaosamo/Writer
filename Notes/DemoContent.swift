//
//  DemoContent.swift
//  Notes
//
//  DEBUG only: launch with -demoContent YES to get an in-memory library of sample
//  notes for screenshots and App Store previews. Never touches real notes or iCloud.
//
//  Mac scenes, also launch arguments: -demoWindowSize 1440x900, -demoSelect <note title>, -demoCaret YES,
//  -demoSearch <text>, -demoMatch <index>, -demoScript search (animated search for a preview)
//

#if DEBUG
import CoreData
#if os(macOS)
import AppKit
#endif

enum DemoContent {
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "demoContent")
    }

    static func seed(_ context: NSManagedObjectContext) {
        let day: TimeInterval = 24 * 60 * 60
        var index: Int16 = 0

        func note(_ title: String, _ text: String, daysAgo: Double, folder: Folder? = nil) {
            let item = Item(context: context)
            item.id = UUID()
            item.title = title
            item.note = text
            item.date = Date().addingTimeInterval(-daysAgo * day)
            item.orderIndex = index
            item.folder = folder
            index += 1
        }

        func folder(_ name: String, _ order: Int16) -> Folder {
            let folder = Folder(context: context)
            folder.id = UUID()
            folder.name = name
            folder.orderIndex = order
            return folder
        }

        note("Morning pages", """
        Woke before the alarm. The light was soft and grey, and for a moment there was nothing to do.

        Coffee in the garden. Write first. Think later.
        """, daysAgo: 0)
        note("Groceries", """
        - milk
        - bread
        - apples
        [x] call mom
        [ ] water the garden
        """, daysAgo: 1)
        note("Reading list", """
        - Walden
        - Bird by Bird
        - Essays in Idleness
        - The Overstory
        """, daysAgo: 2)

        let novel = folder("Novel", 0)
        note("Chapter one", """
        The house at the end of the road had no name, only a number painted over twice.

        Mara found the key where her grandmother said it would be: under the third stone, cold and a little rusted, as if it had been waiting.

        Inside, everything was quiet. Not empty. Quiet.

        Through the kitchen window the garden had gone wild: roses over the fence, mint in the cracks of the path, a pear tree nobody had pruned in years.

        She stood there a long time. Somewhere in that garden was the reason she had come.
        """, daysAgo: 1, folder: novel)
        note("Characters", """
        Mara: thirty-one, cartographer, maps places she has never been.
        Ilan: the neighbour who waters plants that aren't his.
        """, daysAgo: 4, folder: novel)

        let ideas = folder("Ideas", 1)
        note("Small things", """
        - a clock that only shows the season
        - letters you can open in ten years
        - a garden planted by walking
        """, daysAgo: 3, folder: ideas)

        context.saveIfNeeded()
    }

    #if os(macOS)
    // -demoWindowSize 1440x900: content size in points, so screenshots come out at exact App Store sizes
    static func sizeWindow() {
        guard let value = UserDefaults.standard.string(forKey: "demoWindowSize") else { return }
        let size = value.split(separator: "x").compactMap { Double($0) }
        guard size.count == 2, let window = NSApp.windows.first(where: \.isVisible) else { return }
        window.setContentSize(NSSize(width: size[0], height: size[1]))
        window.center()
    }
    #endif
}
#endif
