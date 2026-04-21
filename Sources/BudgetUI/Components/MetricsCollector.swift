import Foundation
#if canImport(MetricKit)
import MetricKit
#endif

/// Subscribes to MetricKit so hangs, crashes, and launch issues surface in
/// Xcode Organizer's Metrics view without any third-party SDK.
/// Payloads are captured by Apple and delivered by the OS — we only log them
/// to the unified log for local diagnostics. Nothing leaves the device.
public final class MetricsCollector: NSObject {

    public static let shared = MetricsCollector()

    public func start() {
        #if canImport(MetricKit) && os(iOS)
        MXMetricManager.shared.add(self)
        #endif
    }
}

#if canImport(MetricKit) && os(iOS)
extension MetricsCollector: MXMetricManagerSubscriber {
    public func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            // Log only aggregates, never raw payload contents to disk.
            if let histo = payload.applicationLaunchMetrics?.histogrammedTimeToFirstDraw {
                print("[MetricKit] launch-time buckets: \(histo.bucketEnumerator.allObjects.count)")
            }
            if let hang = payload.applicationResponsivenessMetrics?.histogrammedApplicationHangTime {
                print("[MetricKit] hang buckets: \(hang.bucketEnumerator.allObjects.count)")
            }
        }
    }

    public func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            if let crashes = payload.crashDiagnostics, !crashes.isEmpty {
                print("[MetricKit] \(crashes.count) crash diagnostic(s)")
            }
            if let hangs = payload.hangDiagnostics, !hangs.isEmpty {
                print("[MetricKit] \(hangs.count) hang diagnostic(s)")
            }
        }
    }
}
#endif
