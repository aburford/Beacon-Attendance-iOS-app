//
//  AppDelegate.swift
//  Beacon Attendance
//
//  Created by Andrew Burford on 5/21/18.
//  Copyright © 2018 Andrew Burford. All rights reserved.
//

import UIKit
import CoreLocation
import UserNotifications

func tmpBeaconPath() -> String {
    return FileManager.default.temporaryDirectory.path + "/current.cb"
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {
    
    var window: UIWindow?
    
    let locationManager = CLLocationManager()
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        NSLog("authorization did change called")
        switch status {
        case .authorizedAlways:
            addStaticBeacon()
        case .authorizedWhenInUse:
            addStaticBeacon()
            break
        default:
            break
        }
    }
    
    func addStaticBeacon() {
        let beaconSet = locationManager.monitoredRegions
        print("monitoring \(beaconSet.count) beacons:")
        for b in beaconSet {
            let a = b as! CLBeaconRegion
            print("\(a.identifier)\t\t\(a.proximityUUID)")
        }
        if !beaconSet.contains(where: {$0.identifier == "static"}) {
            let proximityUUID = UUID(uuidString: "2af63987-32a6-41a4-bd9b-dae585a281cc")
            let beaconID = "static"
            let region = CLBeaconRegion(proximityUUID: proximityUUID!, identifier: beaconID)
            locationManager.startMonitoring(for: region)
        }
    }
    
    func sendNotification(title: String, body: String) {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.getNotificationSettings { (settings) in
            // Do not schedule notifications if not authorized.
            guard settings.authorizationStatus == .authorized else {return}
            
            if settings.alertSetting == .enabled {
                // Schedule an alert-only notification.
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = UNNotificationSound.default()
                
                // Create the trigger as a non-repeating event.
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.01, repeats: false)
                // Create the request
                let uuidString = UUID().uuidString
                let request = UNNotificationRequest(identifier: uuidString,
                                                    content: content, trigger: trigger)
                
                // Schedule the request with the system.
                let notificationCenter = UNUserNotificationCenter.current()
                
                notificationCenter.add(request) { (error) in
                    if error != nil {
                        // handle error
                    }
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        NSLog("in range of beacon: \(region.identifier)")
        // TODO: find out if this method is only called once at beginning of the hour
        let session = APIWrapper.sharedInstance
        if session.auth_token != nil {
            if region.identifier == "static" {
                if UserDefaults.standard.object(forKey: "lastSyncDate") as? String != todayStr() {
                    // delete the old beacon hashes
                    print("today's hashes have not yet been retrieved from server, deleting old hashes")
                    removeBeaconsForPeriod(nil, earlierPeriods: nil)
                    // TODO: if app is open we could show loading indicator?
                    session.requestBeacons(delegate: self)
                } // else todays hashes are already loaded
            } else {
                // we have about 5 seconds to startRanging in order to get the major and minor values
                // TODO: find out if that's actually true by testing stuff with app closed
                locationManager.startRangingBeacons(in: region as! CLBeaconRegion)
            }
        } // else user not logged in
    }
    
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        if let beacon = beacons.first {
            let path = tmpBeaconPath()
            let prev = CryptoBeacon(json: FileManager.default.contents(atPath: path))
            
            print("ranged beacon with major: \(String(beacon.major.intValue, radix: 16)) minor: \(String(beacon.minor.intValue, radix: 16))")
            // load current cb from cache file
            // this may return nil beacause we don't aren't monitoring for any beacons for that minute, but we are for the hour
            if let cb = FileWrapper().loadCachedBeacon(beacon: beacon) {
                // save the CryptoBeacon to /tmp/current.cb
                FileManager.default.createFile(atPath: path, contents: try! JSONEncoder().encode(cb), attributes: nil)
                if prev?.attendance_code != cb.attendance_code || prev?.period != cb.period, let last = UserDefaults.standard.object(forKey: "lastNotifiedPeriod"), last as! Int != cb.period {
                    // tell the user to open the app immediately (before that hash stops being advertised)
                    sendNotification(title: "Open the app immediately to sign in", body: "You must immediately verify your presence to be marked \(cb.attendance_code) for period \(cb.period)")
                    // only notify them once per period
                    UserDefaults.standard.set(cb.period, forKey: "lastNotifiedPeriod")
                } // else the user has already been notified for this period and attendance code
            } else {
                print("extraneous beacon")
            }
            locationManager.stopRangingBeacons(in: region)
        } else {
            print("didRangeCalled with empty array")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        NSLog("exited region: \(region.identifier)")
        if let current = CryptoBeacon(json: FileManager.default.contents(atPath: tmpBeaconPath())), let beacon = region as? CLBeaconRegion, beacon.proximityUUID == UUIDforHash(current.hashes.uuid) {
            try! FileManager.default.removeItem(atPath: tmpBeaconPath())
        }
    }
    
    func removeBeaconsForPeriod(_ period: Int?, earlierPeriods: Bool?) {
        if period != nil {
            let keepMonitoring = FileWrapper().removeCacheForPeriod(period!, earlierPeriods: earlierPeriods!)
            for reg in locationManager.monitoredRegions {
                if !keepMonitoring.contains((reg as! CLBeaconRegion).proximityUUID) && reg.identifier != "static" {
                    locationManager.stopMonitoring(for: reg)
                }
            }
        } else {
            // stop listening for all beacons
            for b in locationManager.monitoredRegions {
                if b.identifier != "static" {
                    locationManager.stopMonitoring(for: b)
                }
            }
            FileWrapper.shared.removeCached()
        }
        if let homeVC = self.window?.rootViewController as? HomeViewController {
            homeVC.reloadPeriodsCV()
        }
    }
    
    func beaconsReceived(error: APIError?, beacons: [CryptoBeacon]?) {
        if error == nil {
            UserDefaults.standard.set(todayStr(), forKey: "lastSyncDate")
            // start monitoring for each uuid
            var uuids: [UUID] = []
            for beacon in beacons! {
                let uuid = UUIDforHash(beacon.hashes.uuid)
                if !uuids.contains(uuid) {
                    // don't just start monitoring for them, because .monitoredRegions() is not immediately updated
                    uuids.append(uuid)
                }
            }
            for i in 0..<uuids.count {
                // identifiers just say if beacon is static or CryptoBeacon
                locationManager.startMonitoring(for: CLBeaconRegion(proximityUUID: uuids[i], identifier: "CryptoBeacon\(i)"))
            }
            // store all of the CryptoBeacons to /tmp so we can look them up using uuid/major/minor values later
            // this will also overwrite the old cache
            FileWrapper.shared.saveCache(beacons: beacons!)
            DispatchQueue.main.async {
                let homeVC = self.window?.rootViewController as! HomeViewController
                print("reloading periodsCV")
                homeVC.reloadPeriodsCV()
            }
        } else {
            print("hashes request error")
            switch error! {
            case .connectionError(let msg):
                // only notify them if it's after 7:28
                if Date() > Calendar.current.date(bySettingHour: 7, minute: 28, second: 49, of: Date())! {
                    if UserDefaults.standard.object(forKey: "lastNotificationDate") as? String != todayStr() {
                        sendNotification(title: msg, body: "You must connect to Amity-Secure wifi in order be signed in to any classes today")
                        UserDefaults.standard.set(todayStr(), forKey: "lastNotificationDate")
                    }
                }
            default:
                // I don't think this should ever happen
                print("hashes request failed - without a connection error...??")
                break
            }
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let homeVC = self.window?.rootViewController as! HomeViewController
        // tell homeVC to check /tmp for current.cb
        homeVC.checkForNewBeacon()
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        let path = tmpBeaconPath()
        let prev = CryptoBeacon(json: FileManager.default.contents(atPath: path))
        print("prev: " + String(describing: prev))
        
        print("last sync date: \(String(describing: UserDefaults.standard.object(forKey: "lastSyncDate")))")
        print("last notification date:\(String(describing: UserDefaults.standard.object(forKey: "lastNotificationDate")))")
        print("last notificed period: \(String(describing: UserDefaults.standard.object(forKey: "lastNotifiedPeriod") as? Int))")
        if UserDefaults.standard.object(forKey: "lastNotifiedPeriod") as? Int == 3 {
            print("last notified period 3")
        }
        //        UserDefaults.standard.removeObject(forKey: "lastNotificationDate")
//                FileWrapper.shared.removeCached()
//        
//                for b in locationManager.monitoredRegions {
//                    locationManager.stopMonitoring(for: b)
//                }
        
        
        
        // Override point for customization after application launch.
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.delegate = self
        //        let category = UNNotificationCategory(identifier: "Verification Request", actions: [], intentIdentifiers: [], options: UNNotificationCategoryOptions())
        //        notificationCenter.setNotificationCategories([category])
        locationManager.delegate = self
        
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        let homeVC = self.window?.rootViewController as! HomeViewController
        // tell homeVC to check /tmp for current.cb
        homeVC.checkForNewBeacon()
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
}

func basicAlert(title: String, msg: String, dismiss: String, delegate: UIViewController) {
    let alert = UIAlertController(title: title, message: msg, preferredStyle: UIAlertControllerStyle.alert)
    alert.addAction(UIAlertAction(title: dismiss, style: UIAlertActionStyle.default, handler: nil))
    DispatchQueue.main.async() {
        delegate.present(alert, animated: true, completion: nil)
    }
}

func todayStr() -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-M-d"
    return f.string(from: Date())
}
