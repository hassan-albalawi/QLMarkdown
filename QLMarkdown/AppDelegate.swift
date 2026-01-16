//
//  AppDelegate.swift
//  QLMarkdown
//
//  Created by Sbarex on 09/12/20.
//

import Cocoa
import Sparkle

// MARK: - Recent Files Manager
class RecentFilesManager {
    static let shared = RecentFilesManager()
    private let key = "qlmarkdown-recent-files"
    private let maxRecentFiles = 10

    private init() {}

    var recentFiles: [URL] {
        get {
            guard let bookmarks = UserDefaults.standard.array(forKey: key) as? [Data] else {
                return []
            }
            return bookmarks.compactMap { data in
                var isStale = false
                guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) else {
                    return nil
                }
                // Skip stale bookmarks to files that no longer exist
                if isStale || !FileManager.default.fileExists(atPath: url.path) {
                    return nil
                }
                return url
            }
        }
        set {
            let bookmarks = newValue.prefix(maxRecentFiles).compactMap { url -> Data? in
                try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            }
            UserDefaults.standard.set(bookmarks, forKey: key)
        }
    }

    func addRecentFile(_ url: URL) {
        var files = recentFiles
        // Remove if already exists (will be re-added at top)
        files.removeAll { $0.path == url.path }
        // Add to beginning
        files.insert(url, at: 0)
        // Store (will be trimmed to maxRecentFiles)
        recentFiles = files
    }

    func clearRecentFiles() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    var userDriver: SPUStandardUserDriver?
    var updater: SPUUpdater?
    @IBOutlet weak var recentFilesMenu: NSMenu?

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let file = URL(fileURLWithPath: filename)
        return openFileInNewWindow(file)
    }

    /// Opens a file in a new window
    @discardableResult
    func openFileInNewWindow(_ file: URL) -> Bool {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let windowController = storyboard.instantiateController(withIdentifier: "PreferencesWindowController") as? PreferencesWindowController,
              let controller = windowController.contentViewController as? ViewController else {
            return false
        }

        // Show the window first, then open the file
        windowController.showWindow(nil)

        // Open the file and track in recent files
        let result = controller.openMarkdown(file: file)
        return result
    }

    /// Adds a file to recent files list
    func addToRecentFiles(_ url: URL) {
        RecentFilesManager.shared.addRecentFile(url)
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        for window in sender.windows {
            if let wc = window.windowController as? PreferencesWindowController, !wc.windowShouldClose(window) {
                return .terminateCancel
            } 
        }
        
        return .terminateNow
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        let hostBundle = Bundle.main
        let applicationBundle = hostBundle;
        
        self.userDriver = SPUStandardUserDriver(hostBundle: hostBundle, delegate: nil)
        self.updater = SPUUpdater(hostBundle: hostBundle, applicationBundle: applicationBundle, userDriver: self.userDriver!, delegate: nil)
        
        do {
            try self.updater!.start()
        } catch {
            print("Failed to start updater with error: \(error)")
            
            let alert = NSAlert()
            alert.messageText = "Updater Error"
            alert.informativeText = "The Updater failed to start. For detailed error information, check the Console.app log."
            alert.addButton(withTitle: "Close").keyEquivalent = "\u{1b}"
            alert.runModal()
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        XPCWrapper.invalidateSharedConnection()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    @IBAction func checkForUpdates(_ sender: Any)
    {
        self.updater?.checkForUpdates()
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool
    {
        if menuItem.action == #selector(self.checkForUpdates(_:)) {
            return self.updater?.canCheckForUpdates ?? false
        }
        if menuItem.identifier?.rawValue.starts(with: "update_refresh") ?? false {
            menuItem.state = ((NSApplication.shared.delegate as? AppDelegate)?.updater?.updateCheckInterval == TimeInterval(menuItem.tag)) ? .on : .off
        } else if menuItem.identifier?.rawValue == "auto refresh" {
            if let a = UserDefaults.standard.value(forKey: "auto-refresh") as? Bool {
                menuItem.state = a ? .on : .off
            }
        }
        return true
    }
    
    
    @IBAction func installCLITool(_ sender: Any) {
        guard let srcApp = Bundle.main.url(forResource: "qlmarkdown_cli", withExtension: nil) else {
            return
        }
        let dstApp = URL(fileURLWithPath: "/usr/local/bin/qlmarkdown_cli")
        
        let alert1 = NSAlert()
        alert1.messageText = "The tool will be installed in \(dstApp.path) \nDo you want to continue?"
        alert1.informativeText = "You can call the tool directly from this path: \n\(srcApp.path) \n\nManually install from a Terminal shell with this command: \nln -sfv \"\(srcApp.path)\" \"\(dstApp.path)\""
        alert1.alertStyle = .informational
        alert1.addButton(withTitle: "OK").keyEquivalent = "\r"
        alert1.addButton(withTitle: "Cancel").keyEquivalent = "\u{1b}"
        guard alert1.runModal() == .alertFirstButtonReturn else {
            return
        }
        guard access(dstApp.deletingLastPathComponent().path, W_OK) == 0 else {
            let alert = NSAlert()
            alert.messageText = "Unable to install the tool: \(dstApp.deletingLastPathComponent().path) is not writable"
            alert.informativeText = "You can directly call the tool from this path: \n\(srcApp.path) \n\nManually install from a Terminal shell with this command: \nln -sfv \"\(srcApp.path)\" \"\(dstApp.path)\""
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Close").keyEquivalent = "\u{1b}"
            alert.runModal()
            return
        }
        
        let alert = NSAlert()
        do {
            try FileManager.default.createSymbolicLink(at: dstApp, withDestinationURL: srcApp)
            alert.messageText = "Command line tool installed"
            alert.informativeText = "You can call it from this path: \(dstApp.path)"
            alert.alertStyle = .informational
        } catch {
            alert.messageText = "Unable to install the command line tool"
            alert.informativeText = "(\(error.localizedDescription))\n\nYou can manually install the tool from a Terminal shell with this command: \nln -sfv \"\(srcApp.path)\" \"\(dstApp.path)\""
            alert.alertStyle = .critical
        }
        alert.runModal()
    }
    
    @IBAction func revealCLITool(_ sender: Any) {
        let u = URL(fileURLWithPath: "/usr/local/bin/qlmarkdown_cli")
        if FileManager.default.fileExists(atPath: u.path) {
            // Open the Finder to the settings file.
            NSWorkspace.shared.activateFileViewerSelecting([u])
        } else {
            let alert = NSAlert()
            alert.messageText = "The command line tool is not installed."
            alert.alertStyle = .warning
            
            alert.runModal()
        }
    }
    
    @IBAction func onUpdateRate(_ sender: NSMenuItem) {
        updater?.updateCheckInterval = TimeInterval(sender.tag)
    }
    
    @IBAction func buyMeACoffee(_ sender: Any?) {
        let url = URL(string: "https://www.buymeacoffee.com/sbarex")!
        NSWorkspace.shared.open(url)
    }

    /// Creates a new window
    @IBAction func newWindow(_ sender: Any?) {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let windowController = storyboard.instantiateController(withIdentifier: "PreferencesWindowController") as? PreferencesWindowController else {
            return
        }
        windowController.showWindow(nil)
    }

    /// Opens a recent file
    @IBAction func openRecentFile(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        openFileInNewWindow(url)
    }

    /// Clears the recent files list
    @IBAction func clearRecentFiles(_ sender: Any?) {
        RecentFilesManager.shared.clearRecentFiles()
    }
}

// MARK: - NSMenuDelegate for Recent Files
extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu == recentFilesMenu else { return }

        // Remove all items except "Clear Menu" (last item)
        while menu.items.count > 1 {
            menu.removeItem(at: 0)
        }

        let recentFiles = RecentFilesManager.shared.recentFiles

        if recentFiles.isEmpty {
            let emptyItem = NSMenuItem(title: "No Recent Files", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.insertItem(emptyItem, at: 0)
            menu.insertItem(NSMenuItem.separator(), at: 1)
        } else {
            for (index, url) in recentFiles.enumerated() {
                let item = NSMenuItem(title: url.lastPathComponent, action: #selector(openRecentFile(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = url
                // Show full path in tooltip
                item.toolTip = url.path
                menu.insertItem(item, at: index)
            }
            menu.insertItem(NSMenuItem.separator(), at: recentFiles.count)
        }
    }
}

