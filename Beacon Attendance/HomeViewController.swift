
//
//  HomeViewController.swift
//  Beacon Attendance
//
//  Created by Andrew Burford on 5/22/18.
//  Copyright © 2018 Andrew Burford. All rights reserved.
//

import UIKit
import CoreLocation

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
            addStaticBeacon()
            break
        case .authorizedAlways:
            addStaticBeacon()
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
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
        if !beaconSet.contains(where: {$0.identifier == "static"}) {
            let proximityUUID = UUID(uuidString: "2af63987-32a6-41a4-bd9b-dae585a281cc")
            let beaconID = "static"
            let region = CLBeaconRegion(proximityUUID: proximityUUID!, identifier: beaconID)
            locationManager.startMonitoring(for: region)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        let session = APIWrapper.sharedInstance
        if session.auth_token != nil {
            if region.identifier == "static" {
                // check if we already have today's hashes
                if manager.monitoredRegions.count == 1 {
                    for hash in session.requestHashes() {
                        // start monitoring for each hash
                        // convert hashes to uuids by inserting dashes (-)
                        
                        let uuid = UUID(uuidString: hash)
                        // i guess we can just set the identifier to the hash?
                        let region = CLBeaconRegion(proximityUUID: uuid!, identifier: hash)
                        manager.startMonitoring(for: region)
                    }
                } // else the hashes are already loaded
            } else {
                // sign in the user
                session.signIn(hash: region.identifier)
            }
        } // else the user is not logged in
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
