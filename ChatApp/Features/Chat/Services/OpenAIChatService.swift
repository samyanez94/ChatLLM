//
//  OpenAIChatService.swift
//  ChatApp
//
//  Created by Samuel Yanez on 8/15/26.
//

/// Maintains one GPT-5.6 Luna conversation using the OpenAI Responses API.
final class OpenAIChatService: ChatProviding {
	private let client: any OpenAIResponseCreating

	private var previousResponseId: String?

	private var isGenerating = false

	/// Information about GPT-5.6 Luna for the current OpenAI configuration.
	let model: ChatModel

	/// Creates a live OpenAI conversation when a local API key is available.
	/// - Parameter configuration: The local OpenAI credential configuration.
	init?(configuration: OpenAIConfiguration = OpenAIConfiguration()) {
		guard let apiKey = configuration.apiKey else {
			return nil
		}
		self.client = OpenAIClient(apiKey: apiKey)
		self.model = OpenAIModelCatalog.luna(configuration: configuration)
	}

	/// Creates an OpenAI conversation with an injected response client.
	/// - Parameters:
	///   - client: The response client used for each turn.
	///   - model: GPT-5.6 Luna metadata for this conversation.
	init(
		client: any OpenAIResponseCreating,
		model: ChatModel = OpenAIModelCatalog.luna(
			configuration: OpenAIConfiguration(apiKey: "injected-client")
		)
	) {
		self.client = client
		self.model = model
	}

	/// Generates a reply and continues from the last successful OpenAI response.
	func generateReply(to message: String) async throws -> String {
		guard isGenerating == false else {
			throw OpenAIChatServiceError.responseInProgress
		}
		isGenerating = true
		defer {
			isGenerating = false
		}

		let response = try await client.createResponse(
			model: model.id,
			input: message,
			previousResponseId: previousResponseId
		)
		previousResponseId = response.id
		return response.outputText
	}
}
