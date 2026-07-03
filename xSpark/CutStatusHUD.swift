//
//  CutStatusHUD.swift
//  xSpark
//
//  Floating HUD shown on Cmd+X — stays until paste or timeout.
//  Ported from MenuSpark; adds a "press ⌘V to move here" hint line
//  to act as the Cmd+X explanation prompt.
//

import Cocoa

final class CutStatusHUD {
    static let shared = CutStatusHUD()

    private var hudWindow: NSWindow?
    private var fileNames: [String] = []
    private var hideTimer: Timer?

    private init() {}

    // MARK: - Public

    func show(fileNames: [String]) {
        DispatchQueue.main.async {
            self.fileNames = fileNames
            self.hideImmediate()
            self.createAndShow()
            self.resetTimer()
        }
    }

    /// Single-line status message mode (minimal style).
    func showStatus(_ message: String) {
        DispatchQueue.main.async {
            self.fileNames = [message]
            self.hideImmediate()
            self.createAndShow(isStatusOnly: true)
            self.resetTimer()
        }
    }

    func hide() {
        DispatchQueue.main.async {
            self.hideTimer?.invalidate()
            self.hideTimer = nil

            guard let window = self.hudWindow else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                window.animator().alphaValue = 0.0
            }) {
                window.orderOut(nil)
                self.hudWindow = nil
                self.fileNames = []
            }
        }
    }

    // MARK: - Private

    private func hideImmediate() {
        hideTimer?.invalidate()
        hideTimer = nil
        hudWindow?.orderOut(nil)
        hudWindow = nil
    }

    private func resetTimer() {
        hideTimer?.invalidate()
        // Auto-dismiss after 10s so it never lingers forever.
        hideTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }

    private func createAndShow(isStatusOnly: Bool = false) {
        let contentView = CutStatusContentView(fileNames: fileNames, isStatusOnly: isStatusOnly)

        let fittingSize = contentView.fittingSize
        let width = fittingSize.width
        let height = fittingSize.height

        // Screen bottom-center, above the Dock.
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let windowFrame = NSRect(
            x: screenFrame.midX - width / 2,
            y: screenFrame.minY + 80 - 16,
            width: width,
            height: height
        )

        let window = NSPanel(
            contentRect: windowFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .statusBar
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.contentView = contentView

        window.alphaValue = 0.0
        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
        }

        hudWindow = window
    }
}

// MARK: - Content View

private final class CutStatusContentView: NSView {

    private let fileNames: [String]
    private let isStatusOnly: Bool

    private let shadowPadding: CGFloat = 16
    private var cardView: NSView?

    init(fileNames: [String], isStatusOnly: Bool = false) {
        self.fileNames = fileNames
        self.isStatusOnly = isStatusOnly
        super.init(frame: .zero)
        self.wantsLayer = true
        setupView()
    }

    required init?(coder: NSCoder) { return nil }

    override func layout() {
        super.layout()
        if let card = cardView, let layer = card.layer {
            layer.shadowPath = CGPath(roundedRect: card.bounds, cornerWidth: layer.cornerRadius, cornerHeight: layer.cornerRadius, transform: nil)
        }
    }

    private var titleText: String {
        if isStatusOnly {
            return fileNames.first ?? ""
        }
        let count = fileNames.count
        let format = count == 1
            ? NSLocalizedString("Cut 1 item", comment: "HUD cut single")
            : NSLocalizedString("Cut %d items", comment: "HUD cut multiple")
        return String(format: format, count)
    }

    private var hintText: String? {
        guard !isStatusOnly else { return nil }
        return NSLocalizedString("Press ⌘V to move here", comment: "HUD cut hint")
    }

    private func calculateCardSize() -> NSSize {
        let titleFont = NSFont.systemFont(ofSize: 14, weight: .medium)
        let hintFont = NSFont.systemFont(ofSize: 11, weight: .regular)

        let titleW = titleText.size(withAttributes: [.font: titleFont]).width
        let hintW = hintText?.size(withAttributes: [.font: hintFont]).width ?? 0

        // icon(20) + spacing(8) + text, plus 20pt padding each side
        let contentW = 20 + 8 + max(titleW, hintW) + 40
        let width = max(contentW, 160)

        let height: CGFloat = hintText == nil ? 44 : 56
        return NSSize(width: width, height: height)
    }

    override var fittingSize: NSSize {
        let cardSize = calculateCardSize()
        return NSSize(width: cardSize.width + shadowPadding * 2, height: cardSize.height + shadowPadding * 2)
    }

    private func setupView() {
        let themeGreen = NSColor(red: 0.1, green: 0.7, blue: 0.3, alpha: 1.0)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        let card = NSView()
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.98).cgColor
        card.layer?.cornerRadius = 22
        card.layer?.borderWidth = 0.5
        card.layer?.borderColor = NSColor.systemGray.withAlphaComponent(0.2).cgColor

        card.layer?.shadowColor = NSColor.black.cgColor
        card.layer?.shadowOffset = CGSize(width: 0, height: 2)
        card.layer?.shadowRadius = 8
        card.layer?.shadowOpacity = 0.15

        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        self.cardView = card

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: shadowPadding),
            card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -shadowPadding),
            card.topAnchor.constraint(equalTo: topAnchor, constant: shadowPadding),
            card.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -shadowPadding)
        ])

        // Icon + title row
        let icon = NSImageView()
        if let img = NSImage(systemSymbolName: "scissors", accessibilityDescription: "Cut") {
            icon.image = img
            icon.contentTintColor = themeGreen
        }
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 20).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let titleLabel = NSTextField(labelWithString: titleText)
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = themeGreen

        let titleRow = NSStackView(views: [icon, titleLabel])
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 8

        // Outer stack: title row (+ optional hint)
        let outer = NSStackView()
        outer.orientation = .vertical
        outer.alignment = .centerX
        outer.spacing = 2
        outer.translatesAutoresizingMaskIntoConstraints = false
        outer.addArrangedSubview(titleRow)

        if let hint = hintText {
            let hintLabel = NSTextField(labelWithString: hint)
            hintLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
            hintLabel.textColor = NSColor(white: 0.45, alpha: 1.0)
            outer.addArrangedSubview(hintLabel)
        }

        card.addSubview(outer)

        NSLayoutConstraint.activate([
            outer.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            outer.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            outer.leadingAnchor.constraint(greaterThanOrEqualTo: card.leadingAnchor, constant: 20),
            outer.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -20)
        ])
    }
}
