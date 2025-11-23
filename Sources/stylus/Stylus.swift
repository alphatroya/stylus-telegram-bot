import Foundation

// MARK: - Stylus

@main
struct Stylus {
    static func main() async throws {
        let config = try await readConfig(provider: yamlProvider())
        let bot = Bot(config: config)
        try await bot.run()
    }
}
