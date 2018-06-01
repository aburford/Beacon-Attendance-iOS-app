//
//  FileWrapper.swift
//  Beacon Attendance
//
//  Created by Andrew Burford on 5/28/18.
//  Copyright © 2018 Andrew Burford. All rights reserved.
//

import UIKit
import CoreLocation

class FileWrapper: NSObject {
    static let shared: FileWrapper = FileWrapper()
    let manager: FileManager
    let verifiedPath: String
    let cachePath: String
    
    override init() {
        manager = FileManager.default
        verifiedPath = manager.temporaryDirectory.path + "/verified.cbs"
        cachePath = manager.temporaryDirectory.path + "/cache.cbs"
    }
    
    func saveCache(beacons: [CryptoBeacon]) {
        manager.createFile(atPath: cachePath, contents: try! JSONEncoder().encode(beacons), attributes: nil)
    }
    
    func saveVerified(cb: CryptoBeacon?) -> Bool {
        if let cb = cb {
            var cbArr = getVerified()
            cbArr.append(cb)
            return manager.createFile(atPath: verifiedPath, contents: try! JSONEncoder().encode(cbArr), attributes: nil)
        }
        return false
    }
    
    func periods() -> [Int] {
        var periods: [Int] = []
        for beacon in getCached() {
            if !periods.contains(beacon.period) {
                periods.append(beacon.period)
            }
        }
        return periods
    }
    
    func loadCachedBeacon(beacon: CLBeacon) -> CryptoBeacon {
        return getCached().first { (cb) -> Bool in
            Int(cb.hashes.major, radix: 16)! == beacon.major.intValue && Int(cb.hashes.minor, radix: 16)! == beacon.minor.intValue && UUIDforHash(cb.hashes.uuid) == beacon.proximityUUID
        }!
    }
    
    func removeCached() {
        // remove all the cached beacons
        try? manager.removeItem(atPath: cachePath)
    }
    
    func getCached() -> [CryptoBeacon] {
        if let file = manager.contents(atPath: cachePath) {
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
    
    // remove the beacons and return their UUID's
    func removeCacheForPeriod(_ period: Int, earlierPeriods: Bool) -> [UUID] {
        if let file = manager.contents(atPath: cachePath) {
            let json = try! JSONSerialization.jsonObject(with: file, options: [])
            let dictArr = json as! [[String:Any]]
            var keepArr: [CryptoBeacon] = []
            var retArr: [UUID] = []
            for beaconDict in dictArr {
                let cb = CryptoBeacon(json: beaconDict)!
                if earlierPeriods && cb.period < period || cb.period == period {
                    retArr.append(UUIDforHash(cb.hashes.uuid))
                } else {
                    keepArr.append(cb)
                }
            }
            manager.createFile(atPath: cachePath, contents: try! JSONEncoder().encode(keepArr), attributes: nil)
            return retArr
        } else {
            return []
        }
    }
    
    func removeVerified(_ beacons: [CryptoBeacon]?) {
        if beacons == nil {
            // remove all the beacons
            try? manager.removeItem(atPath: verifiedPath)
        } else {
            // only remove beacons in beacons
            var cbArr = getVerified()
            for b in beacons! {
                cbArr.remove(at: cbArr.index(where: { (saved) -> Bool in
                    saved.hashes.uuid == b.hashes.uuid
                })!)
            }
            manager.createFile(atPath: verifiedPath, contents: try! JSONEncoder().encode(cbArr), attributes: nil)
        }
    }
    
    func getVerified() -> [CryptoBeacon] {
        if let file = manager.contents(atPath: verifiedPath) {
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
