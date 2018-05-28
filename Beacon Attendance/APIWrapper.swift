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

struct CryptoBeacon: Encodable {
    let date: String
    let period: Int
    let attendance_code: Int
    let hash: String
    
    init?(json: [String: Any]) {
        guard let date = json["date"] as? String, let period = json["period"] as? Int, let attendance_code = json["attendance_code"] as? Int, let hash = json["hash"] as? String else {
            return nil
        }
        self.date = date
        self.period = period
        self.attendance_code = attendance_code
        self.hash = hash
    }
    
    init?(json: Data?) {
        do {
            guard let jsonData = json else {
                return nil
            }
            let jsonObj = try JSONSerialization.jsonObject(with: jsonData)
            let dict = jsonObj as! [String:Any]
            self.init(json: dict)
        } catch {
            return nil
        }
    }
    
    init?(json: String) {
        self.init(json: json.data(using: String.Encoding.utf8)!)
    }
}

func hashToUUID(hash: String) -> UUID {
    // add dashes (-) to hashes
    // 2af63987-32a6-41a4-bd9b-dae585a281cc
    // 8-4-4-4-12
    var uuid = hash
    for i in [8, 13, 18, 23] {
        uuid.insert("-", at: uuid.index(uuid.startIndex, offsetBy: i))
    }
    return UUID(uuidString: uuid)!
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
    
    func requestBeacons(delegate: AppDelegate) {
        // load the hashes from the server using the auth_token
        // JSON will be a set of beacons
        // each beacon has a period number, date, and hash
        var urlRequest = URLRequest(url: URL(string: "http://192.168.1.18:3000/api/hashes")!)
        // set up token authentication
        urlRequest.setValue("Token \(auth_token!)", forHTTPHeaderField: "Authorization")
        let task = URLSession.shared.dataTask(with: urlRequest, completionHandler: { data, response, error in
            print("data task completion handler started")
            if let error = error {
                // client side error such as no connection
                print("client side error")
                delegate.beaconsReceived(error: APIError.connectionError(msg: error.localizedDescription), beacons: nil)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode) else {
                    print("server response code not in the 200's")
                    delegate.beaconsReceived(error: APIError.serverError(msg: "Server returned an error"), beacons: nil)
                    return
            }
            //
            //            if let mimeType = httpResponse.mimeType,
            //                mimeType == "application/json",
            if let data = data {
                print("parsing JSON for hashes response")
                // parse the JSON so you can access elements of the array
                // convert the elements (CryptoBeacons) back into JSON string to store in CLRegion.identifier
                let json = try? JSONSerialization.jsonObject(with: data, options: [])
                if let dictArr = json as? [[String:Any]] {
                    var cbArr: [CryptoBeacon] = []
                    for cb in dictArr {
                        cbArr.append(CryptoBeacon(json: cb)!)
                    }
                    delegate.beaconsReceived(error: nil, beacons: cbArr)
                } else {
                    print("error parsing json")
                    delegate.beaconsReceived(error: APIError.connectionError(msg: "Error parsing response from server"), beacons: nil)
                }
            }
        })
        task.resume()
    }
    
    func signIn(hash: String) {
        print("signing in user for hash: " + hash)
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
