import Foundation
import FoundationModels

extension String {
    func ask(with instructions: String) async throws -> String {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: self)
        return response.content
    }
}
