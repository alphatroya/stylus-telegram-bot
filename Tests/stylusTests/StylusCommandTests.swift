import ArgumentParser
@testable import stylus
import Testing

@Suite("Stylus Command Tests")
struct StylusCommandTests {
    @Test
    func `Help output includes --readeck flag and description`() {
        let helpText = Stylus.fullMessage(for: CleanExit.helpRequest(Stylus()))
        #expect(helpText.contains("--readeck"))
        #expect(helpText.contains("Run Readeck sync mode"))
    }

    @Test
    func `No flags defaults readeck to false`() throws {
        let command = try Stylus.parse([])
        #expect(command.readeck == false)
    }

    @Test
    func `Readeck flag sets readeck to true`() throws {
        let command = try Stylus.parse(["--readeck"])
        #expect(command.readeck == true)
    }

    @Test
    func `Short readeck flag sets readeck to true`() throws {
        let command = try Stylus.parse(["-r"])
        #expect(command.readeck == true)
    }

    @Test
    func `Unknown flag throws error`() {
        #expect(throws: (any Error).self) {
            _ = try Stylus.parse(["--unknown-flag"])
        }
    }
}
