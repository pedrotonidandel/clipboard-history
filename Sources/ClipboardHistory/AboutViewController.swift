import AppKit

/// Shown in the About tab of Settings, next to the small logo.
let developerName = "Grupo Quote"
let developerURL = URL(string: "https://grupoquote.com.br")!

final class AboutViewController: NSViewController {
    override func loadView() {
        let appIconImage = Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
            .flatMap { NSImage(contentsOf: $0) }
        let appIcon: NSImageView
        if let appIconImage {
            appIcon = NSImageView(image: appIconImage)
            appIcon.imageScaling = .scaleProportionallyUpOrDown
        } else {
            appIcon = NSImageView(image: NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: nil) ?? NSImage())
            appIcon.symbolConfiguration = .init(pointSize: 36, weight: .regular)
        }
        appIcon.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = NSTextField(labelWithString: "Clipboard History")
        nameLabel.font = .boldSystemFont(ofSize: 15)
        nameLabel.alignment = .center

        let versionLabel = NSTextField(labelWithString: "Version 1.0")
        versionLabel.font = .systemFont(ofSize: 11)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center

        let developerLabel = NSTextField(labelWithString: "Made by \(developerName)")
        developerLabel.font = .systemFont(ofSize: 12)
        developerLabel.textColor = .secondaryLabelColor

        let logoImage = Bundle.main.url(forResource: "Logo", withExtension: "png")
            .flatMap { NSImage(contentsOf: $0) }
        let logo = ClickableImageView(image: logoImage ?? NSImage())
        logo.imageScaling = .scaleProportionallyUpOrDown
        logo.translatesAutoresizingMaskIntoConstraints = false
        logo.isHidden = logoImage == nil
        logo.url = developerURL
        logo.toolTip = developerURL.absoluteString

        let creditRow = NSStackView(views: [developerLabel, logo])
        creditRow.orientation = .horizontal
        creditRow.alignment = .centerY
        creditRow.spacing = 6

        let stack = NSStackView(views: [appIcon, nameLabel, versionLabel, creditRow])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 220))
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            appIcon.widthAnchor.constraint(equalToConstant: 64),
            appIcon.heightAnchor.constraint(equalToConstant: 64),
            logo.widthAnchor.constraint(equalToConstant: 26),
            logo.heightAnchor.constraint(equalToConstant: 17)
        ])
        view = contentView
    }
}
