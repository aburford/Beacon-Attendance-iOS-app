
//
//  HomeViewController.swift
//  Beacon Attendance
//
//  Created by Andrew Burford on 5/22/18.
//  Copyright © 2018 Andrew Burford. All rights reserved.
//

import UIKit
import CoreLocation
import UserNotifications

class HomeViewController: UIViewController, CLLocationManagerDelegate  {
    let locationManager = CLLocationManager()
    
    @IBAction func logoutPressed(_ sender: Any) {
        let session = APIWrapper.sharedInstance
        do {
            try session.logout()
            performSegue(withIdentifier: "toLoginView", sender: self)
        } catch {
            // alert user that something went wrong
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let session = APIWrapper.sharedInstance
        NSLog("home view loaded", session.identifier)
        if session.auth_token != nil {
            NSLog("auth token found, setting view to visible")
            DispatchQueue.main.async() {
                self.view.isHidden = false
            }
            let center = UNUserNotificationCenter.current()
            // Request permission to display alerts and play sounds.
            center.requestAuthorization(options: [.alert, .sound])
            { (granted, error) in
                // do error handling (or don't bother)
                if !granted {
                    basicAlert(title: "Please enable notifications in Settings", msg: "Otherwise you will not know when to open the app to sign in", dismiss: "Okay", delegate: self)
                }
            }
            checkLocationAuth()
        } else {
            DispatchQueue.main.async() {
                [unowned self] in
                self.performSegue(withIdentifier: "toLoginView", sender: self)
            }
        }
    }
    
    func checkLocationAuth() {
        locationManager.delegate = self
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
            break
            
        case .restricted, .denied:
            // alert user that they must enable location services
            break
            
        case .authorizedWhenInUse:
            NSLog("authorized when in use")
            addStaticBeacon()
            break
        case .authorizedAlways:
            NSLog("location auth is set up correctly")
            addStaticBeacon()
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        NSLog("authorization did change called")
        switch status {
        case .authorizedAlways:
            addStaticBeacon()
        case .authorizedWhenInUse:
//            UIAlertController you will have to open the app yourself if you want to sign in
            addStaticBeacon()
            break
        default:
//            UIAlertController the app won't work if you don't enable location services
            break
        }
    }
    
    func addStaticBeacon() {
        let beaconSet = locationManager.monitoredRegions
        NSLog("monitoring beacons:")
        for b in beaconSet {
            NSLog(b.identifier)
        }
        if !beaconSet.contains(where: {$0.identifier == "static"}) {
            let proximityUUID = UUID(uuidString: "2af63987-32a6-41a4-bd9b-dae585a281cc")
            let beaconID = "static"
            let region = CLBeaconRegion(proximityUUID: proximityUUID!, identifier: beaconID)
            locationManager.startMonitoring(for: region)
        }
    }
    //  MOVE THIS TO THE APP DELEGATE (i think)
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        sendNotification(title: "in range of a beacon!", body: "ID: \(region.identifier)")
        print("in range of beacon: \(region.identifier)")
        let session = APIWrapper.sharedInstance
        if session.auth_token != nil {
            if region.identifier == "static" {
                // check if we already have today's hashes
                if manager.monitoredRegions.count == 1 {
                    for hash in session.requestHashes() {
                        // start monitoring for each hash
                        // convert hashes to uuids by inserting dashes (-)
                        
                        let uuid = UUID(uuidString: hash)
                        // set the identifier to the hash for easy access later
                        let region = CLBeaconRegion(proximityUUID: uuid!, identifier: hash)
                        manager.startMonitoring(for: region)
                    }
                } // else the hashes are already loaded
            } else {
                // sign in the user
                session.signIn(hash: region.identifier)
            }
        } // else user not logged in
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("exited region: \(region.identifier)")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
    
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
    
}
