import Foundation

/// Settings in `~/.config/workplace-tracker/config.json`.
/// `officeSSID` is required for detection; the other keys have defaults.
public struct Config: Decodable {
    public var officeSSID: String?
    public var csvPath = "~/Documents/workplace.csv"

    public var csvURL: URL {
        URL(fileURLWithPath: (csvPath as NSString).expandingTildeInPath)
    }

    public static let fileURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/workplace-tracker/config.json")

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        officeSSID = try c.decodeIfPresent(String.self, forKey: .officeSSID)
        csvPath = try c.decodeIfPresent(String.self, forKey: .csvPath) ?? csvPath
    }

    private enum CodingKeys: String, CodingKey {
        case officeSSID, csvPath
    }

    /// Falls back to defaults when the file is missing or invalid.
    public static func load(from url: URL = fileURL) -> Config {
        guard let data = try? Data(contentsOf: url) else { return Config() }
        return (try? JSONDecoder().decode(Config.self, from: data)) ?? Config()
    }
}
