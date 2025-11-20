import Foundation

enum ConfigPath {
    // MARK: Static Computed Properties

    static var path: String {
        // Search for config file in common locations
        if let foundPath = findConfigFile() {
            return foundPath.path
        }

        // Default to current directory
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return currentDir.appendingPathComponent("config.yaml").path
    }

    // MARK: Static Functions

    private static func findConfigFile() -> URL? {
        let configFileName = "config.yaml"

        // Check current directory first
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let currentConfig = currentDir.appendingPathComponent(configFileName)
        if FileManager.default.fileExists(atPath: currentConfig.path) {
            return currentConfig
        }

        // Check home directory
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let homeConfig = homeDir.appendingPathComponent(".config")
            .appendingPathComponent("stylus")
            .appendingPathComponent(configFileName)
        if FileManager.default.fileExists(atPath: homeConfig.path) {
            return homeConfig
        }

        // Check application support directory
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let appConfig = appSupport.appendingPathComponent("stylus").appendingPathComponent(configFileName)
            if FileManager.default.fileExists(atPath: appConfig.path) {
                return appConfig
            }
        }

        return nil
    }
}
