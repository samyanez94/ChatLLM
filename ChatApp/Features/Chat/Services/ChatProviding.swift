//
//  ChatProviding.swift
//  ChatProviding
//
//  Created by Samuel Yanez on 8/14/26.

protocol ChatProviding {
    func generateReply(to message: String) async throws -> String
}
