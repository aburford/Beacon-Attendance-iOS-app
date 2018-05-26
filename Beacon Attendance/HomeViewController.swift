
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

class HomeViewController: UIViewController  {
    
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
        if session.auth_token != nil {
            print("auth token found: \(session.auth_token!)")
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

        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.locationManager.requestAlwaysAuthorization()
            break
            
        case .restricted, .denied:
            basicAlert(title: "Please Enable Location Services", msg: "Otherwise we cannot verify your location to sign you in to study hall", dismiss: "Okay", delegate: self)
            break
            
        case .authorizedWhenInUse:
            NSLog("authorized when in use")
            
            break
        case .authorizedAlways:
            NSLog("location auth is set up correctly")
            
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
