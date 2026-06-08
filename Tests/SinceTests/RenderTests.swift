import XCTest
import AppKit
@testable import Since

/// Renders ItemRowView off-screen so the row redesign can be inspected without
/// driving a live menu bar dropdown. Dot colors are asserted from pixels;
/// full-menu PNGs are dumped to /tmp/since-rows when SINCE_RENDER is set, for
/// eyeballing layout, highlight legibility, and light/dark rendering.
final class RenderTests: XCTestCase {
    let now = date(2026, 6, 6, hour: 12)

    // A representative spread covering every dot status and both sections.
    var sampleContents: [RowContent] {
        [
            content("Brita filter", daysAgo(50, from: now), every: "6w"),            // overdue chore
            content("Haircut", daysAgo(21, from: now), every: "6w"),                 // neutral chore
            content("Vacuum", daysAgo(200, from: now)),                              // neutral chore, no target
            content("Alcohol", daysAgo(200, from: now), kind: "streak",
                    history: [daysAgo(400, from: now), daysAgo(300, from: now)]),    // record streak
            content("Smoking", daysAgo(30, from: now), kind: "streak",
                    history: [daysAgo(400, from: now)]),                             // non-record streak
            content("Soda", daysAgo(10, from: now), kind: "streak"),                 // empty-history streak
        ]
    }

    // MARK: - Dot color assertions (todos 7 & 8)

    func testOverdueDotIsAmberAndFilled() {
        let c = content("Brita filter", daysAgo(50, from: now), every: "6w")
        XCTAssertEqual(c.status, .overdue)
        let px = dotCenterPixel(c)
        XCTAssertGreaterThan(px.alphaComponent, 0.5, "overdue dot is filled")
        XCTAssertGreaterThan(px.redComponent, 0.7, "amber is red-dominant")
        XCTAssertGreaterThan(px.redComponent, px.blueComponent, "amber, not blue")
    }

    func testRecordStreakDotIsGreenAndFilled() {
        let c = content("Alcohol", daysAgo(200, from: now), kind: "streak",
                        history: [daysAgo(400, from: now), daysAgo(300, from: now)])
        XCTAssertEqual(c.status, .record)
        let px = dotCenterPixel(c)
        XCTAssertGreaterThan(px.alphaComponent, 0.5, "record dot is filled")
        XCTAssertGreaterThan(px.greenComponent, px.redComponent, "green-dominant")
        XCTAssertGreaterThan(px.greenComponent, px.blueComponent, "green-dominant")
    }

    func testNeutralDotIsHollow() {
        // A non-record streak and an empty-history streak are both neutral and
        // hollow — the dot's center is clear, only its ring is drawn.
        for c in [
            content("Smoking", daysAgo(30, from: now), kind: "streak",
                    history: [daysAgo(400, from: now)]),
            content("Soda", daysAgo(10, from: now), kind: "streak"),
            content("Haircut", daysAgo(21, from: now), every: "6w"),
        ] {
            XCTAssertEqual(c.status, .neutral)
            XCTAssertLessThan(dotCenterPixel(c).alphaComponent, 0.5,
                              "neutral dot is hollow at center")
        }
    }

    // MARK: - Visual dumps (set SINCE_RENDER=1 to generate)

    func testDumpMenuImages() throws {
        guard ProcessInfo.processInfo.environment["SINCE_RENDER"] != nil else {
            throw XCTSkip("set SINCE_RENDER=1 to dump menu PNGs")
        }
        let dir = URL(fileURLWithPath: "/tmp/since-rows")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (name, app) in [("light", NSAppearance(named: .aqua)!),
                            ("dark", NSAppearance(named: .darkAqua)!)] {
            for highlight in [nil, 0, 3] as [Int?] {
                let suffix = highlight.map { "-hl\($0)" } ?? ""
                let url = dir.appendingPathComponent("menu-\(name)\(suffix).png")
                try renderMenu(sampleContents, appearance: app, highlight: highlight)
                    .write(to: url)
            }
        }
        print("wrote menu PNGs to \(dir.path)")
    }

    // MARK: - Helpers

    private func content(_ name: String, _ lastDone: Date, kind: String = "",
                         every: String = "", history: [Date] = []) -> RowContent {
        let item = Item(name: name, lastDone: lastDone, history: history,
                        kind: kind, every: every)
        let overdue = item.isOverdue(now: now)
        return RowContent(
            name: name + (overdue ? " ⚠" : ""),
            date: dateLabel(lastDone, now: now),
            time: relative(lastDone, now: now),
            status: status(for: item, now: now),
            accessibility: rowLabel(item, now: now))
    }

    /// The pixel at the dot's center, rendered over a transparent background
    /// in light appearance so filled dots read opaque and hollow ones clear.
    private func dotCenterPixel(_ c: RowContent) -> NSColor {
        let view = ItemRowView(content: c, metrics: ItemRowView.metrics(for: [c]))
        let app = NSAppearance(named: .aqua)!
        view.appearance = app
        let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
        app.performAsCurrentDrawingAppearance {
            view.cacheDisplay(in: view.bounds, to: rep)
        }
        let cx = Int(ItemRowView.leading + ItemRowView.dotDiameter / 2)
        let cy = Int(ItemRowView.height / 2)
        return rep.colorAt(x: cx, y: cy)!.usingColorSpace(.deviceRGB)!
    }

    private func renderMenu(_ contents: [RowContent], appearance: NSAppearance,
                            highlight: Int?) -> Data {
        let metrics = ItemRowView.metrics(for: contents)
        let w = metrics.totalWidth, rowH = ItemRowView.height
        let pad: CGFloat = 6

        // A flipped container stands in for the menu: rows composite over its
        // background the same way subviews would in a real window.
        let menu = PreviewMenu(frame: NSRect(
            x: 0, y: 0, width: w, height: rowH * CGFloat(contents.count) + pad * 2))
        menu.appearance = appearance
        menu.background = appearance.name == .darkAqua
            ? NSColor(white: 0.16, alpha: 1) : NSColor(white: 0.96, alpha: 1)
        for (i, c) in contents.enumerated() {
            let view = ItemRowView(content: c, metrics: metrics)
            view.highlightedForPreview = (i == highlight)
            view.setFrameOrigin(NSPoint(x: 0, y: pad + rowH * CGFloat(i)))
            menu.addSubview(view)
        }

        let rep = menu.bitmapImageRepForCachingDisplay(in: menu.bounds)!
        appearance.performAsCurrentDrawingAppearance {
            menu.cacheDisplay(in: menu.bounds, to: rep)
        }
        return rep.representation(using: .png, properties: [:])!
    }
}

/// A flipped, background-filling stand-in for the menu, for preview dumps.
private final class PreviewMenu: NSView {
    var background: NSColor = .white
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        background.setFill()
        bounds.fill()
    }
}
