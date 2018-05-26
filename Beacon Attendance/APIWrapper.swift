//
//  APIWrapper.swift
//  Beacon Attendance
//
//  Created by Andrew Burford on 5/22/18.
//  Copyright © 2018 Andrew Burford. All rights reserved.
//

import UIKit
import Security

enum APIError: Error {
    case credentialError(msg: String)
    case keychainError(msg: String)
    case connectionError(msg: String)
    case serverError(msg: String)
}

class APIWrapper: NSObject {
    static let sharedInstance: APIWrapper = APIWrapper()
    var auth_token: String?
    let server = "www.example.com"

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
    
    func requestHashes() throws -> [Dictionary<String, Any>] {
        // load the hashes from the server using the auth_token
        // JSON will be a set of beacons
        // each beacon has a period number, date, and hash
        let response = """
        [
        { "period":2, "date":"2018-5-25", "hash":"1a48fa06-3cff-47ef-af1f-011e23d4e6b0" }
        { "period":2, "date":"2018-5-25", "hash":"16596d62-1537-47a5-8350-660b3fa0a872" }
        { "period":3, "date":"2018-5-25", "hash":"7c6195bb-942a-4c71-9ee9-6a4fb94f6788" }
        { "period":3, "date":"2018-5-25", "hash":"34b8c621-e8e6-4c72-991d-2144db6c7be2" }
        ]
        """.data(using: String.Encoding.ascii)
        let json = try? JSONSerialization.jsonObject(with: response!, options: [])
        if let dictArr = json as? [[String:Any]] {
            return dictArr
        } else {
            print("error parsing json")
            //            throw Error
            throw APIError.connectionError(msg: "no connection")
        }
    }
    
    func signIn(hash: String) {
        
    }
    
    func logout() throws {
        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                    kSecAttrServer as String: server]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw APIError.keychainError(msg: "Keychain item not found") }
        NSLog("successfully deleted keychain itme")
    }
    
    func authenticate(user: String, pass: String, delegate: LoginViewController) {
        //        authenticate with server to get token
        var urlRequest = URLRequest(url: URL(string: "http://192.168.1.18:3000/api/get_token")!)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = "user=\(user)&pass=\(pass)".data(using: String.Encoding.ascii)
        
        let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                // client side error such as no connection
                print("client side error")
                delegate.loginResponse(error: APIError.connectionError(msg: error.localizedDescription))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode) else {
                    print("server response code not in the 200's")
                    delegate.loginResponse(error: APIError.serverError(msg: "Server returned an error"))
                    return
            }
            if let mimeType = httpResponse.mimeType,
                mimeType == "application/json",
                let data = data {
                let json = try? JSONSerialization.jsonObject(with: data, options: [])
                if let dict = json as? [String:Any] {
                    print(dict)
                    self.auth_token = dict["auth_token"] as? String
                    let password = self.auth_token!.data(using: String.Encoding.utf8)!
                    let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                                kSecAttrAccount as String: user,
                                                kSecAttrServer as String: self.server,
                                                kSecValueData as String: password]
                    
                    let status = SecItemAdd(query as CFDictionary, nil)
                    guard status == errSecSuccess else {
                        print("weird keychain error")
                        delegate.loginResponse(error: APIError.keychainError(msg: String(status)))
                        return
                    }
                    print("token successfully stored in keychain")
                    delegate.loginResponse(error: nil)
                } else {
                    print("error parsing json")
                    delegate.loginResponse(error: APIError.serverError(msg: "JSON could not be parsed"))
                }
            }
        }
        task.resume()
    }
    
}
