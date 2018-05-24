//
//  APIWrapper.swift
//  Beacon Attendance
//
//  Created by Andrew Burford on 5/22/18.
//  Copyright © 2018 Andrew Burford. All rights reserved.
//

import UIKit
import Security

enum AuthError: Error {
    case credentialError(msg: String)
    case keychainError(msg: String)
    case connectionError(msg: String)
}

class APIWrapper: NSObject {
    static let sharedInstance: APIWrapper = APIWrapper()
    var auth_token: String?
    let server = "www.example.com"
    var identifier: String = "default"
    override init() {
//        search keychain for auth_token
//        if not found, set to nil
        
        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                    kSecAttrServer as String: server,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnAttributes as String: true,
                                    kSecReturnData as String: true]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess {
            if let existingItem = item as? [String : Any] {
                let tokenData = existingItem[kSecValueData as String] as? Data
                auth_token = String(data: tokenData!, encoding: String.Encoding.ascii)!
            } else {
                NSLog("password not retrieved properly from keychain")
                auth_token = nil
            }
        } else {
            NSLog("The auth token was not found in keychain")
            auth_token = nil
        }
        super.init()
    }
    
//    func hashesLoaded() -> Bool {
//        // checks if today's hashes have been retrieved from the server yet
//
//        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
//                                    kSecMatchLimit as String: kSecMatchLimitAll,
//                                    kSecReturnAttributes as String: true,
//                                    kSecReturnData as String: true]
//        var allItems: CFTypeRef?
//        let status = SecItemCopyMatching(query as CFDictionary, &allItems)
//        if status == errSecSuccess {
//            // allItems is an array containing the results
//            return allItems!.length > 1
//        } // else the user is not logged in, or other keychain error
//        return false
//    }
    
    func requestHashes() -> Set<String> {
        // load the hashes from the server using the auth_token
        
        return ["16596d62-1537-47a5-8350-660b3fa0a872", "7c6195bb-942a-4c71-9ee9-6a4fb94f6788", "34b8c621-e8e6-4c72-991d-2144db6c7be2"]
    }
    
    func signIn(hash: String) {
        
    }
    
    func logout() throws {
        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                    kSecAttrServer as String: server]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw AuthError.keychainError(msg: "Keychain item not found") }
        NSLog("successfully deleted keychain itme")
    }
    
    func authenticate(user: String, pass: String) throws {
//        authenticate with server to get token
        if false {
            throw AuthError.credentialError(msg: "Username/password incorrect")
        }
        
        
//        if authenticated, store in keychain and store in auth_token constant
//        else, throw errors
        
        // pass should be replaced with auth_token
        auth_token = "token received from server"
        let password = auth_token!.data(using: String.Encoding.utf8)!
        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                    kSecAttrAccount as String: user,
                                    kSecAttrServer as String: server,
                                    kSecValueData as String: password]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            NSLog("weird keychain error")
            throw AuthError.keychainError(msg: String(status)) }
        NSLog("token successfully stored in keychain")
    }
    
}
