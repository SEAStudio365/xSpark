//
//  ToastNotification.swift
//  xSpark
//
//  Toast notification system — visual feedback for Cut & Paste operations.
//  Ported from MenuSpark.
//

import Cocoa

// MARK: - Toast Type

enum ToastType {
    case success
    case error
    case info
    case warning

    var backgroundColor: NSColor {
        return NSColor.white.withAlphaComponent(0.98)
    }

    var textColor: NSColor {
        switch self {
        case .success:
            return NSColor(red: 0.1, green: 0.7, blue: 0.3, alpha: 1.0)
        case .error:
            return NSColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0)
        case .info:
            return NSColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1.0)
        case .warning:
            return NSColor(red: 0.8, green: 0.6, blue: 0.1, alpha: 1.0)
        }
    }

    var iconColor: NSColor { return textColor }

    var icon: NSImage? {
        let symbolName: String
        let description: String

        switch self {
        case .success:
            symbolName = "checkmark.circle.fill"
            description = "Success"
        case .error:
            symbolName = "xmark.circle.fill"
            description = "Error"
        case .info:
            symbolName = "info.circle.fill"
            description = "Info"
        case .warning:
            symbolName = "exclamationmark.triangle.fill"
            description = "Warning"
        }

        return NSImage(systemSymbolName: symbolName, accessibilityDescription: description)
    }
}

// MARK: - Toast Notification Manager

final class ToastNotificationManager {
    static let shared = ToastNotificationManager()

    private var currentToast: NSWindow?
    private var hideTimer: Timer?
    private var onClickAction: (() -> Void)?

    private init() {}

    func showToast(message: String, type: ToastType, duration: TimeInterval = 2.5, onClick: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            self.hideCurrentToast()
            self.createAndShowToast(message: message, type: type, duration: duration, onClick: onClick)
        }
    }

    private func hideCurrentToast() {
        hideTimer?.invalidate()
        hideTimer = nil

        if let toast = currentToast {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                toast.animator().alphaValue = 0.0
            }) {
                toast.orderOut(nil)
            }
            currentToast = nil
        }
        onClickAction = nil
    }

    private func createAndShowToast(message: String, type: ToastType, duration: TimeInterval, onClick: (() -> Void)?) {
        self.onClickAction = onClick

        let toastWindow = createToastWindow(message: message, type: type)
        currentToast = toastWindow

        toastWindow.alphaValue = 0.0
        toastWindow.level = .statusBar

        toastWindow.ignoresMouseEvents = (onClick == nil)
        toastWindow.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            toastWindow.animator().alphaValue = 1.0
        })

        let timer = Timer(timeInterval: duration, repeats: false) { [weak self] _ in
            self?.hideToastWithAnimation()
        }
        RunLoop.main.add(timer, forMode: .common)
        hideTimer = timer

        xsLog("xSpark [Toast]: Showing \(type) toast: \(message)")
    }

    private func createToastWindow(message: String, type: ToastType) -> NSWindow {
        let horizontalPadding: CGFloat = 20
        let iconSize: CGFloat = 20
        let spacing: CGFloat = 8

        let font = NSFont.systemFont(ofSize: 14, weight: .medium)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: type.textColor
        ]

        let textSize = message.size(withAttributes: textAttributes)
        let contentWidth = iconSize + spacing + textSize.width + horizontalPadding * 2

        let pillHeight: CGFloat = 44
        let pillWidth = max(contentWidth, 120)

        let shadowPadding: CGFloat = 16
        let totalWidth = pillWidth + shadowPadding * 2
        let totalHeight = pillHeight + shadowPadding * 2

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let toastFrame = NSRect(
            x: screenFrame.midX - totalWidth / 2,
            y: screenFrame.minY + 80 - shadowPadding,
            width: totalWidth,
            height: totalHeight
        )

        let window = NSPanel(
            contentRect: toastFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let contentView = ToastContentView(message: message, type: type)
        window.contentView = contentView

        if onClickAction != nil {
            let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleToastClick))
            contentView.addGestureRecognizer(clickGesture)
        }

        return window
    }

    @objc private func handleToastClick() {
        onClickAction?()
        hideToastWithAnimation()
    }

    private func hideToastWithAnimation() {
        guard let toast = currentToast else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            toast.animator().alphaValue = 0.0
        }) {
            toast.orderOut(nil)
            if self.currentToast == toast {
                self.currentToast = nil
            }
        }

        hideTimer?.invalidate()
        hideTimer = nil
        onClickAction = nil
    }
}

// MARK: - Toast Content View

private final class ToastContentView: NSView {
    private let message: String
    private let type: ToastType

    private let shadowPadding: CGFloat = 16
    private var cardView: NSView?

    init(message: String, type: ToastType) {
        self.message = message
        self.type = type
        super.init(frame: .zero)
        self.wantsLayer = true
        setupView()
    }

    required init?(coder: NSCoder) { return nil }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        let card = NSView()
        card.wantsLayer = true
        card.layer?.backgroundColor = type.backgroundColor.cgColor
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

        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(containerView)

        let stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false

        if let iconImage = type.icon {
            let iconView = NSImageView(image: iconImage)
            iconView.imageScaling = .scaleProportionallyUpOrDown
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.contentTintColor = type.iconColor
            stackView.addArrangedSubview(iconView)

            NSLayoutConstraint.activate([
                iconView.widthAnchor.constraint(equalToConstant: 20),
                iconView.heightAnchor.constraint(equalToConstant: 20)
            ])
        }

        let label = NSTextField(labelWithString: message)
        label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = type.textColor
        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        stackView.addArrangedSubview(label)

        containerView.addSubview(stackView)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: card.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            stackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
    }

    override func layout() {
        super.layout()
        if let card = cardView, let layer = card.layer {
            let radius = card.bounds.height / 2
            layer.cornerRadius = radius
            layer.shadowPath = CGPath(roundedRect: card.bounds, cornerWidth: radius, cornerHeight: radius, transform: nil)
        }
    }
}
