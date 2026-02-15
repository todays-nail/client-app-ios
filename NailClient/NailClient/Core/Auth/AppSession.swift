//
//  AppSession.swift
//  NailClient
//

import Foundation

struct AppSession: Sendable, Equatable {
    var accessToken: String
    var refreshToken: String
}

