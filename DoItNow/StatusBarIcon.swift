import AppKit

enum StatusBarIcon {
    static func make(count: Int, appearance: NSAppearance) -> NSImage {
        let size = NSSize(width: 26, height: 20)
        var rendered: NSImage?
        appearance.performAsCurrentDrawingAppearance {
            rendered = render(size: size, count: count)
        }
        let image = rendered ?? NSImage(size: size)
        image.isTemplate = false
        return image
    }

    private static func render(size: NSSize, count: Int) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(origin: .zero, size: size)

        drawCheckmark(in: rect)
        drawBadge(count: count, in: rect)

        image.unlockFocus()
        return image
    }

    private static func drawCheckmark(in rect: NSRect) {
        let baseConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .heavy)
        let paletteConfig = NSImage.SymbolConfiguration(paletteColors: [NSColor.labelColor])
        let config = baseConfig.applying(paletteConfig)

        guard let check = NSImage(systemSymbolName: "checklist", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return }

        let checkSize = check.size
        let drawRect = NSRect(
            x: (rect.width - checkSize.width) / 2 - 3,
            y: (rect.height - checkSize.height) / 2 + 1,
            width: checkSize.width,
            height: checkSize.height
        )
        check.draw(in: drawRect)
    }

    private static func drawBadge(count: Int, in rect: NSRect) {
        let display = count > 99 ? "99+" : "\(count)"
        let font = NSFont.systemFont(ofSize: 9, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let textSize = (display as NSString).size(withAttributes: attrs)
        let badgeHeight: CGFloat = 11
        let horizontalPadding: CGFloat = 3
        let badgeWidth = max(textSize.width + horizontalPadding * 2, badgeHeight)
        let badgeRect = NSRect(
            x: rect.maxX - badgeWidth,
            y: 0,
            width: badgeWidth,
            height: badgeHeight
        )

        let fillColor: NSColor = count > 0 ? .systemRed : .secondaryLabelColor
        fillColor.setFill()
        let path = NSBezierPath(
            roundedRect: badgeRect,
            xRadius: badgeHeight / 2,
            yRadius: badgeHeight / 2
        )
        path.fill()

        let textPoint = NSPoint(
            x: badgeRect.midX - textSize.width / 2,
            y: badgeRect.midY - textSize.height / 2
        )
        (display as NSString).draw(at: textPoint, withAttributes: attrs)
    }
}
