//
//  APIWrapper.swift
//  Beacon Attendance
//
//  Created by Andrew Burford on 5/22/18.
//  Copyright © 2018 Andrew Burford. All rights reserved.
//

import UIKit

enum AuthError: Error {
    case credentialError(msg: String)
    case connectionError(msg: String)
}

class APIWrapper: NSObject {
    static let sharedInstance: APIWrapper = APIWrapper()
    let auth_token: String?
    
    
    override init() {
//        search keychain for auth_token
//        if not found, set to nil
        auth_token = nil
        super.init()
    }
    
    func authenticate(user: String, pass: String) throws {
//        authenticate with server to get token
//        if authenticated store in keychain and store in auth_token constant
//        else, throw errors
    }
}
