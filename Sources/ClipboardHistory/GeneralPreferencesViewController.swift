import AppKit

final class GeneralPreferencesViewController: NSViewController {
    private let recorder: ShortcutRecorderView
    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
    var onShortcutChanged: ((HotkeyShortcut) -> Void)?

    init(currentShortcut: HotkeyShortcut) {
        recorder = ShortcutRecorderView(shortcut: currentShortcut)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        let titleLabel = NSTextField(labelWithString: "Global Shortcut")
        titleLabel.font = .boldSystemFont(ofSize: 13)

        let hintLabel = NSTextField(labelWithString: "Click the field, then press a new key combo or mouse button.")
        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = .secondaryLabelColor

        recorder.translatesAutoresizingMaskIntoConstraints = false
        recorder.onRecorded = { [weak self] shortcut in
            ShortcutStore.save(shortcut)
            self?.onShortcutChanged?(shortcut)
        }

        let resetButton = NSButton(title: "Reset to Default (⌘⇧V)", target: self, action: #selector(resetToDefault))
        resetButton.bezelStyle = .rounded

        let divider = NSBox()
        divider.boxType = .separator

        let startupTitle = NSTextField(labelWithString: "Startup")
        startupTitle.font = .boldSystemFont(ofSize: 13)

        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(toggleLaunchAtLogin)
        launchAtLoginCheckbox.state = LaunchAtLogin.isEnabled ? .on : .off

        let stack = NSStackView(views: [
            titleLabel, recorder, hintLabel, resetButton,
            divider,
            startupTitle, launchAtLoginCheckbox
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.setCustomSpacing(16, after: resetButton)
        stack.setCustomSpacing(16, after: divider)
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 280))
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            recorder.widthAnchor.constraint(equalToConstant: 200),
            divider.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48)
        ])
        view = contentView
    }

    @objc private func resetToDefault() {
        let shortcut = HotkeyShortcut.defaultShortcut
        recorder.shortcut = shortcut
        ShortcutStore.save(shortcut)
        onShortcutChanged?(shortcut)
    }

    @objc private func toggleLaunchAtLogin() {
        let wantsEnabled = launchAtLoginCheckbox.state == .on
        if let errorMessage = LaunchAtLogin.setEnabled(wantsEnabled) {
            launchAtLoginCheckbox.state = wantsEnabled ? .off : .on
            let alert = NSAlert()
            alert.messageText = "Couldn't update Login Item"
            alert.informativeText = errorMessage
            alert.runModal()
        }
    }
}
