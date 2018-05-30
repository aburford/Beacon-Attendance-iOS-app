//
//  FileWrapper.swift
//  Beacon Attendance
//
//  Created by Andrew Burford on 5/28/18.
//  Copyright © 2018 Andrew Burford. All rights reserved.
//

import UIKit

class FileWrapper: NSObject {
    static let shared: FileWrapper = FileWrapper()
    let manager: FileManager
    let path: String
    
    override init() {
        manager = FileManager.default
        path = manager.temporaryDirectory.path + "/verified.cbs"
    }
    
    func saveVerified(cb: CryptoBeacon?) -> Bool {
        if let cb = cb {
            var cbArr = getVerified()
            cbArr.append(cb)
            return manager.createFile(atPath: path, contents: try! JSONEncoder().encode(cbArr), attributes: nil)
        }
        return false
    }
    
    func removeVerified(_ beacons: [CryptoBeacon]?) {
        if beacons == nil {
            // remove all the beacons
            try? manager.removeItem(atPath: path)
        } else {
            // only remove beacons in beacons
            var cbArr = getVerified()
            for b in beacons! {
                cbArr.remove(at: cbArr.index(where: { (saved) -> Bool in
                    saved.hash == b.hash
                })!)
            }
            manager.createFile(atPath: path, contents: try! JSONEncoder().encode(cbArr), attributes: nil)
        }
    }
    
    func getVerified() -> [CryptoBeacon] {
        if let file = manager.contents(atPath: path) {
            let json = try! JSONSerialization.jsonObject(with: file, options: [])
            let dictArr = json as! [[String:Any]]
            var cbArr: [CryptoBeacon] = []
            for cb in dictArr {
                cbArr.append(CryptoBeacon(json: cb)!)
            }
            return cbArr
        } else {
            return []
        }
    }
    
}
