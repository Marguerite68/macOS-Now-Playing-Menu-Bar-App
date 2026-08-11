import Foundation

@MainActor
protocol MediaProvider: AnyObject {
    var identifier: String { get }
    var onMediaChanged: ((MediaInfo?) -> Void)? { get set }

    func currentMedia() async -> MediaInfo?
    func startMonitoring()
    func stopMonitoring()
}
