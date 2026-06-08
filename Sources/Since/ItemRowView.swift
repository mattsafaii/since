import AppKit

/// What one row draws: a leading status dot, the item name (with a ⚠ suffix
/// when overdue), a demoted calendar date, and the elapsed time as the hero.
/// Built in MenuController from an Item; the view itself is presentation-only.
struct RowContent {
    let name: String          // item name, ⚠ appended when overdue
    let date: String          // demoted, e.g. "May 16"
    let time: String          // hero elapsed, e.g. "3 weeks ago"
    let status: RowStatus
    let accessibility: String // full spoken/tooltip text
}

/// Fixed layout shared by every row in one menu build, so names, dates, and
/// times line up in columns and the elapsed time keeps a common trailing edge.
struct RowMetrics {
    var name: CGFloat
    var date: CGFloat
    var time: CGFloat

    var totalWidth: CGFloat {
        ItemRowView.leading + ItemRowView.dotDiameter + ItemRowView.dotGap
            + name + ItemRowView.colGap + date + ItemRowView.colGap + time
            + ItemRowView.trailing
    }
}

/// A custom menu-row view: status dot · name · date · elapsed time, with
/// highlight, click, and accessibility parity with native rows.
final class ItemRowView: NSView {
    // Layout metrics (points). Tuned so the name starts near where a native
    // menu item's text would.
    static let height: CGFloat = 22
    static let leading: CGFloat = 13      // left edge → dot
    static let dotDiameter: CGFloat = 7
    static let dotGap: CGFloat = 8        // dot → name
    static let colGap: CGFloat = 16       // name → date, date → time
    static let trailing: CGFloat = 14     // time → right edge

    static let nameFont = NSFont.menuFont(ofSize: 0)
    static let timeFont = NSFont.monospacedDigitSystemFont(
        ofSize: NSFont.menuFont(ofSize: 0).pointSize, weight: .semibold)
    static let dateFont = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)

    private let content: RowContent
    private let metrics: RowMetrics

    /// Test seam: force the highlighted appearance when rendering a row
    /// outside a live menu (where enclosingMenuItem is nil).
    var highlightedForPreview = false
    private var isHighlighted: Bool {
        highlightedForPreview || (enclosingMenuItem?.isHighlighted ?? false)
    }

    init(content: RowContent, metrics: RowMetrics) {
        self.content = content
        self.metrics = metrics
        super.init(frame: NSRect(x: 0, y: 0, width: metrics.totalWidth, height: Self.height))
        setAccessibilityRole(.menuItem)
        setAccessibilityLabel(content.accessibility)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var isFlipped: Bool { true }  // top-left origin, easier text layout

    // MARK: - Column widths shared across a build

    /// The widest name/date/time across all rows, so every row uses the same
    /// columns and the elapsed times share a trailing edge.
    static func metrics(for contents: [RowContent]) -> RowMetrics {
        func width(_ text: String, _ font: NSFont) -> CGFloat {
            ceil(NSAttributedString(string: text, attributes: [.font: font]).size().width)
        }
        return RowMetrics(
            name: contents.map { width($0.name, nameFont) }.max() ?? 0,
            date: contents.map { width($0.date, dateFont) }.max() ?? 0,
            time: contents.map { width($0.time, timeFont) }.max() ?? 0)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        let highlighted = isHighlighted
        if highlighted {
            // The accent-colored selection fill, matching modern menu rows.
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 0),
                         xRadius: 4, yRadius: 4).fill()
        }

        drawDot(highlighted: highlighted)

        // Text recolors to the selection color when highlighted so nothing
        // low-contrasts against the fill; the date stays demoted either way.
        let primary = highlighted ? NSColor.selectedMenuItemTextColor : .labelColor
        let demoted = highlighted
            ? NSColor.selectedMenuItemTextColor.withAlphaComponent(0.75)
            : .secondaryLabelColor

        let nameX = Self.leading + Self.dotDiameter + Self.dotGap
        let timeX = bounds.maxX - Self.trailing - metrics.time
        let dateX = timeX - Self.colGap - metrics.date

        draw(content.name, font: Self.nameFont, color: primary,
             x: nameX, width: metrics.name, align: .left)
        draw(content.date, font: Self.dateFont, color: demoted,
             x: dateX, width: metrics.date, align: .right)
        draw(content.time, font: Self.timeFont, color: primary,
             x: timeX, width: metrics.time, align: .right)
    }

    private func drawDot(highlighted: Bool) {
        let rect = NSRect(x: Self.leading,
                          y: (bounds.height - Self.dotDiameter) / 2,
                          width: Self.dotDiameter, height: Self.dotDiameter)
        let path = NSBezierPath(ovalIn: rect)
        // On highlight the dot recolors to the selection text color so it stays
        // legible; filled vs hollow still carries the meaning either way.
        let color = highlighted ? NSColor.selectedMenuItemTextColor : dotColor
        color.set()
        switch content.status {
        case .overdue, .record:
            path.fill()
        case .neutral:
            path.lineWidth = 1.2
            path.stroke()
        }
    }

    private var dotColor: NSColor {
        switch content.status {
        case .overdue: return .systemOrange
        case .record: return .systemGreen
        case .neutral: return .tertiaryLabelColor
        }
    }

    private func draw(_ text: String, font: NSFont, color: NSColor,
                      x: CGFloat, width: CGFloat, align: NSTextAlignment) {
        let style = NSMutableParagraphStyle()
        style.alignment = align
        style.lineBreakMode = .byTruncatingTail
        let attr = NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: style,
        ])
        let h = ceil(attr.size().height)
        attr.draw(in: NSRect(x: x, y: (bounds.height - h) / 2, width: width, height: h))
    }

    // MARK: - Highlight tracking

    // AppKit highlights the menu item under the cursor; redraw on enter/exit
    // so the fill and recolored text track the mouse.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds, options: [.mouseEnteredAndExited, .activeAlways],
            owner: self))
    }

    override func mouseEntered(with event: NSEvent) { needsDisplay = true }
    override func mouseExited(with event: NSEvent) { needsDisplay = true }

    // MARK: - Click

    // A custom view doesn't fire the menu item's action on its own; route the
    // click through the menu so target/action and dismissal match native rows.
    override func mouseUp(with event: NSEvent) {
        guard let item = enclosingMenuItem, let menu = item.menu else { return }
        let index = menu.index(of: item)
        menu.cancelTracking()
        if index >= 0 { menu.performActionForItem(at: index) }
    }
}
