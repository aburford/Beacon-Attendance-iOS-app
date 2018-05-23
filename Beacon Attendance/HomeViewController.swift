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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.delegate = self
        
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
            break
            
        case .restricted, .denied:
            // alert user that they must enable location services
            break
            
        case .authorizedWhenInUse:
            // tell them it should be always, not when in use
            break
            
        case .authorizedAlways:
            // the standard UUID should already be added at this point, right?
            break
        }
        
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways:
            // can we check if the standard UUID is registered?
            
            let beaconSet = locationManager.monitoredRegions
            if !beaconSet.contains(where: {$0.identifier == "static"}) {
                let proximityUUID = UUID(uuidString: "2af63987-32a6-41a4-bd9b-dae585a281cc")
                let beaconID = "static"
                let region = CLBeaconRegion(proximityUUID: proximityUUID!, identifier: beaconID)
                locationManager.startRangingBeacons(in: region)
            }
        default:
            // tell the user to enable always
            break
        }
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
