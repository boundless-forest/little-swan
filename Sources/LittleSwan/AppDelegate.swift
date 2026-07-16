import AppKit
import Combine
import LittleSwanCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let statusBarIconSize = NSSize(width: 18, height: 18)
    private static let statusBarTemplateIconName = "LittleSwanMenuBarTemplate"
    private static let statusItemAutosaveName = "LittleSwanStatusItem.v2"

    private var statusItem: NSStatusItem?
    private var panelController: FloatingPanelController?
    private var settingsController: SettingsWindowController?
    private var toggleHotKeyController: GlobalHotKeyController?
    private var resetWindowHotKeyController: GlobalHotKeyController?
    private var resetMainWindowMenuItem: NSMenuItem?
    private var cancellables = Set<AnyCancellable>()
    private let configStore = ConfigStore()
    private let sourceDraftStore = SourceDraftStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureApplicationMenu()

        let viewModel = TranslationViewModel(
            configStore: configStore,
            sourceDraftStore: sourceDraftStore
        )
        panelController = FloatingPanelController(
            rootView: MainPanelView(
                viewModel: viewModel,
                openSettings: { [weak self] in self?.showSettings() }
            ),
            titlebarAccessoryView: MainPanelTitlebarControlsView(
                viewModel: viewModel,
                resetMainWindow: { [weak self] in self?.panelController?.resetPlacementAndSize() },
                openSettings: { [weak self] in self?.showSettings() }
            ),
            configStore: configStore
        )

        configureStatusItem()
        configureGlobalShortcuts()
        panelController?.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        sourceDraftStore.save()
    }

    private func configureApplicationMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        let quitItem = NSMenuItem(title: "Quit Little Swan", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        let resetMainWindowItem = NSMenuItem(
            title: "Reset Main Window Position and Size",
            action: #selector(resetMainWindow),
            keyEquivalent: ""
        )
        resetMainWindowItem.target = self
        apply(configStore.configuration.resetWindowShortcut, to: resetMainWindowItem)
        windowMenu.addItem(resetMainWindowItem)
        resetMainWindowMenuItem = resetMainWindowItem
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // Use an explicit, versioned identity so macOS does not reuse a corrupted
        // automatically generated Control Center record such as `Item-0`.
        item.autosaveName = Self.statusItemAutosaveName
        let image = statusBarIcon()

        item.button?.image = image
        item.button?.imagePosition = .imageOnly
        item.button?.target = self
        item.button?.action = #selector(togglePanelFromStatusItem)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
    }

    private func configureGlobalShortcuts() {
        let toggleHotKeyController = GlobalHotKeyController(identifier: 1) { [weak self] in
            self?.panelController?.toggle()
        }
        let resetWindowHotKeyController = GlobalHotKeyController(identifier: 2) { [weak self] in
            self?.panelController?.resetPlacementAndSize()
        }
        self.toggleHotKeyController = toggleHotKeyController
        self.resetWindowHotKeyController = resetWindowHotKeyController

        configStore.$configuration
            .map(\.toggleShortcut)
            .removeDuplicates()
            .sink { shortcut in
                toggleHotKeyController.update(shortcut: shortcut)
            }
            .store(in: &cancellables)

        configStore.$configuration
            .map(\.resetWindowShortcut)
            .removeDuplicates()
            .sink { [weak self] shortcut in
                resetWindowHotKeyController.update(shortcut: shortcut)
                if let menuItem = self?.resetMainWindowMenuItem {
                    self?.apply(shortcut, to: menuItem)
                }
            }
            .store(in: &cancellables)
    }

    private func apply(_ shortcut: KeyboardShortcutConfiguration, to menuItem: NSMenuItem) {
        menuItem.keyEquivalent = shortcut.menuKeyEquivalent ?? ""
        menuItem.keyEquivalentModifierMask = shortcut.menuModifierFlags.map(NSEvent.ModifierFlags.init(rawValue:)) ?? []
    }

    private func statusBarIcon() -> NSImage? {
        let templateURL = Bundle.main.url(
            forResource: Self.statusBarTemplateIconName,
            withExtension: "png"
        )
        let sourceImage = templateURL.flatMap(NSImage.init(contentsOf:))
            ?? NSImage(named: "LittleSwan")
            ?? NSApp.applicationIconImage
        guard let image = sourceImage?.copy() as? NSImage else { return nil }

        image.size = Self.statusBarIconSize
        image.isTemplate = true
        image.accessibilityDescription = "Little Swan"
        return image
    }

    @objc private func togglePanelFromStatusItem(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu()
            return
        }

        panelController?.toggle()
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        menu.addItem(toggleMenuItem())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Little Swan", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    private func toggleMenuItem() -> NSMenuItem {
        let shortcut = configStore.configuration.toggleShortcut
        let item = NSMenuItem(title: "Open / Hide Little Swan", action: #selector(togglePanelFromMenu), keyEquivalent: shortcut.menuKeyEquivalent ?? "")
        if let menuModifierFlags = shortcut.menuModifierFlags {
            item.keyEquivalentModifierMask = NSEvent.ModifierFlags(rawValue: menuModifierFlags)
        }
        return item
    }

    @objc private func togglePanelFromMenu() {
        panelController?.toggle()
    }

    @objc private func openPanel() {
        panelController?.show()
    }

    @objc private func openSettings() {
        showSettings()
    }

    @objc private func resetMainWindow() {
        panelController?.resetPlacementAndSize()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(
                rootView: SettingsView(configStore: configStore)
            )
        }

        settingsController?.show()
    }
}
