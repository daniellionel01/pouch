import Foundation
import os

/// Notices new screenshots and reports each one once.
///
/// Two sources run side by side and are de-duplicated by path:
/// - **Spotlight** (`NSMetadataQuery` for `kMDItemIsScreenCapture == 1`):
///   finds screenshots wherever they're saved, but only after Spotlight has
///   indexed them (usually ~1 s) and not at all if indexing is off.
/// - **A folder watcher** on the configured screenshot location: reacts as
///   soon as the file appears and doesn't depend on Spotlight. Files are
///   confirmed with `ScreenshotDetector`, not by name.
///
/// Either source alone covers the common case; together they're fast and
/// robust. Only screenshots created after `start()` are reported.
@MainActor
public final class ScreenshotWatcher {
    public var onScreenshot: ((URL) -> Void)?
    public private(set) var isRunning = false

    private let useSpotlight: Bool
    private let folderProvider: @MainActor () -> URL
    private let logger = Logger(subsystem: "com.danielkurz.Pouch", category: "Screenshots")

    private var startDate = Date.distantFuture
    private var seenPaths: Set<String> = []

    private var query: NSMetadataQuery?
    private var queryObservers: [NSObjectProtocol] = []

    private var watchedFolder: URL?
    private var folderSource: DispatchSourceFileSystemObject?
    private var rescanTask: Task<Void, Never>?
    private var locationCheckTimer: Timer?

    public init(useSpotlight: Bool = true, folder: @escaping @MainActor () -> URL = { ScreenshotLocation.current() }) {
        self.useSpotlight = useSpotlight
        self.folderProvider = folder
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        // A little slack so a screenshot taken right as Pouch launches counts.
        startDate = Date().addingTimeInterval(-2)
        seenPaths = []
        if useSpotlight { startQuery() }
        watchFolder(folderProvider())
        // The screenshot location can change while Pouch runs; check now and then.
        locationCheckTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateFolderIfNeeded() }
        }
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        query?.stop()
        query = nil
        queryObservers.forEach(NotificationCenter.default.removeObserver)
        queryObservers = []
        stopWatchingFolder()
        locationCheckTimer?.invalidate()
        locationCheckTimer = nil
    }

    private func report(_ url: URL) {
        let path = url.normalizedFileURL.path
        guard isRunning, !seenPaths.contains(path) else { return }
        seenPaths.insert(path)
        onScreenshot?(URL(fileURLWithPath: path))
    }

    // MARK: - Spotlight

    private func startQuery() {
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(
            format: "%K == 1 AND %K >= %@",
            "kMDItemIsScreenCapture", NSMetadataItemFSCreationDateKey, startDate as NSDate
        )
        query.searchScopes = [NSMetadataQueryLocalComputerScope]
        query.notificationBatchingInterval = 0.2

        for name in [Notification.Name.NSMetadataQueryDidFinishGathering, .NSMetadataQueryDidUpdate] {
            // Delivered on the main queue, so it's safe to assume main-actor isolation.
            let observer = NotificationCenter.default.addObserver(forName: name, object: query, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.collectQueryResults() }
            }
            queryObservers.append(observer)
        }

        if query.start() {
            self.query = query
        } else {
            logger.error("Spotlight query didn't start; relying on the folder watcher")
            queryObservers.forEach(NotificationCenter.default.removeObserver)
            queryObservers = []
        }
    }

    private func collectQueryResults() {
        guard let query else { return }
        // Results must not change while we read them.
        query.disableUpdates()
        defer { query.enableUpdates() }
        for case let item as NSMetadataItem in query.results {
            if let path = item.value(forAttribute: NSMetadataItemPathKey) as? String {
                report(URL(fileURLWithPath: path))
            }
        }
    }

    // MARK: - Folder watcher

    private func watchFolder(_ folder: URL) {
        stopWatchingFolder()
        // O_EVTONLY: open only for change notifications, so we never block
        // the volume from being unmounted.
        let descriptor = open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else {
            logger.error("Can't watch the screenshot folder (errno \(errno)); relying on Spotlight")
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename, .link], queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.folderChanged() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        folderSource = source
        watchedFolder = folder
    }

    private func stopWatchingFolder() {
        folderSource?.cancel()
        folderSource = nil
        watchedFolder = nil
        rescanTask?.cancel()
        rescanTask = nil
    }

    private func updateFolderIfNeeded() {
        let folder = folderProvider()
        if folder.normalizedFileURL != watchedFolder?.normalizedFileURL {
            watchFolder(folder)
        }
    }

    private func folderChanged() {
        scanFolder()
        // screencapture may finish writing metadata a moment after the file
        // shows up, so look once more shortly after the last change.
        rescanTask?.cancel()
        rescanTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.scanFolder()
        }
    }

    private func scanFolder() {
        guard let folder = watchedFolder else { return }
        let keys: [URLResourceKey] = [.creationDateKey, .isRegularFileKey]
        guard let contents = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            return
        }
        for url in contents {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  let created = values.creationDate, created >= startDate,
                  !seenPaths.contains(url.normalizedFileURL.path),
                  ScreenshotDetector.isScreenCapture(url)
            else { continue }
            report(url)
        }
    }
}
