import CoreLocation
import CoreWLAN

/// Reads the current SSID and reports changes on the main queue.
/// macOS returns a nil SSID unless the app has Location Services permission.
final class WiFiMonitor: NSObject, CLLocationManagerDelegate, CWEventDelegate {
    private let client = CWWiFiClient.shared()
    private let location = CLLocationManager()
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        super.init()
        location.delegate = self
        client.delegate = self
        try? client.startMonitoringEvent(with: .ssidDidChange)
    }

    var ssid: String? { client.interface()?.ssid() }

    var isAuthorized: Bool {
        switch location.authorizationStatus {
        case .notDetermined, .restricted, .denied: false
        default: true
        }
    }

    func requestAuthorization() {
        location.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { notify() }

    func ssidDidChangeForWiFiInterface(withName interfaceName: String) { notify() }

    private func notify() {
        DispatchQueue.main.async(execute: onChange)
    }
}
