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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, CLLocationManagerDelegate {
    
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
        print("monitoring beacons:")
        for b in beaconSet {
            let a = b as! CLBeaconRegion
            print("\(a.identifier)\t\(a.proximityUUID)")
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
        print("in range of beacon: \(region.identifier)")
        sendNotification(title: "in range of a beacon!", body: "ID: \(region.identifier)")
        let session = APIWrapper.sharedInstance
        if session.auth_token != nil {
            if region.identifier == "static" {
                // check if we already have today's hashes by saving the date to the identifier
                // because not all hashes will necessarily be removed by the end of the day
                
                let beacons = manager.monitoredRegions
                let today = todayStr()
                // check if any beacons contain today's hashes
                if !beacons.contains(where: { beacon in
                    // should always return false if beacons are out of date
                    if let cb = CryptoBeacon(json: beacon.identifier) {
                        return cb.date == today
                    } else {
                        print("must say static: \(beacon.identifier)")
                        return false
                    }
                }) {
                    // delete the old beacon hashes
                    print("today's hashes have not yet been retrieved from server, deleting old hashes")
                    for b in beacons {
                        if b.identifier != "static" {
                            manager.stopMonitoring(for: b)
                        }
                    }
                    session.requestBeacons(delegate: self)
                } // else todays hashes are already loaded
            } else {
                let path = FileManager.default.temporaryDirectory.path + "current.cb"
                let prev = CryptoBeacon(json: FileManager.default.contents(atPath: path)!)
                let cb = CryptoBeacon(json: region.identifier)!
                // save the CryptoBeacon to /tmp/current.cb
                FileManager.default.createFile(atPath: path, contents: try! JSONEncoder().encode(cb), attributes: nil)
                if prev?.attendance_code != cb.attendance_code || prev?.period != cb.period {
                    // tell the user to open the app immediately (before that hash stops being advertised)
                    sendNotification(title: "Open the app immediately to sign in", body: "You must immediately verify your presence to be marked \(cb.attendance_code) for period \(cb.period)")
                } // else the user has already been notified for this period and attendance code
                
            }
        } // else user not logged in
    }
    
    func todayStr() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
    
    func beaconsReceived(error: APIError?, beacons: [CryptoBeacon]?) {
        if error == nil {
            for beacon in beacons! {
                // start monitoring for each beacon
                // example identifier: 2018-05-25/2/attendance code/1a48fa063cff47efaf1f011e23d4e6b0
                do {
                    let data = try JSONEncoder().encode(beacon)
                    let identifier = String(data: data, encoding: String.Encoding.utf8)
                    print("encoded json: \(identifier ?? "didn't work")")
                    let region = CLBeaconRegion(proximityUUID: hashToUUID(hash: beacon.hash), identifier: identifier!)
                    locationManager.startMonitoring(for: region)
                } catch {
                    print("error creating JSON data from CryptoBeacon instance")
                }
            }
        } else {
            print("hashes request error")
            // handle error
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("exited region: \(region.identifier)")
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        if let options = launchOptions {
            print(options)
        }
        locationManager.delegate = self
        
        NSLog("app launched")
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
