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
                // beacuse not all hashes will necessarily be removed by the end of the day
                
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                let today = f.string(from: Date())
                let beacons = manager.monitoredRegions
                if !beacons.contains(where: {$0.identifier.split(separator: "/")[0] == today }) {
                    // delete the old beacon hashes
                    print("today's hashes have not yet been retrieved from server, deleting old hashes")
                    for b in beacons {
                        if b.identifier != "static" {
                            manager.stopMonitoring(for: b)
                        }
                    }
                    do {
                        for beacon in try session.requestHashes() {
                            // start monitoring for each hash
                            // add dashes (-) to hashes
                            // 2af63987-32a6-41a4-bd9b-dae585a281cc
                            // 8-4-4-4-12
                            var uuid = String(describing: beacon["hash"])
                            for i in [8, 13, 18, 23] {
                                uuid.insert("-", at: uuid.index(uuid.startIndex, offsetBy: i))
                            }
                            print("adding uuid:\(uuid)")
                            // example identifier: 2/2018-05-25/1a48fa06-3cff-47ef-af1f-011e23d4e6b0
                            let identifier = "\(today)/\(String(describing: beacon["period"]))/\(uuid)"
                            
                            let region = CLBeaconRegion(proximityUUID: UUID(uuidString: uuid)!, identifier: identifier)
                            manager.startMonitoring(for: region)
                        }
                    } catch {
                        print("some kind of error occured in requestHashes")
                        // server error or connection error
                        // send notification to user telling them to connect to wifi?
                    }
                    
                } // else the hashes are already loaded
            } else {
                // sign in the user
                do {
                    try session.signIn(hash: region.identifier)
                } catch {
                    // alert the user that they couldn't be signed in
                }
                // stop monitoring for that hash
                
            }
        } // else user not logged in
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("exited region: \(region.identifier)")
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

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
