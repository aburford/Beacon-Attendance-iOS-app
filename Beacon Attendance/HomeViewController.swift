
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
import LocalAuthentication

class HomeViewController: UIViewController, UICollectionViewDataSource  {
    @IBOutlet weak var periodsCV: UICollectionView!
    
    var beacons: [CryptoBeacon] = []
    var beingVerified: CryptoBeacon? = nil
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let set = appDelegate.locationManager.monitoredRegions
        var periods: [Int] = []
        beacons = []
        for b in set {
            if b.identifier != "static" {
                let beacon = CryptoBeacon(json: b.identifier)!
                if !periods.contains(beacon.period) {
                    periods.append(beacon.period)
                    // since this method should always be called once before cellForItemAt
                    beacons.append(beacon)
                }
            }
        }
        beacons.sort { (a, b) -> Bool in
            return a.period < b.period
        }
        return periods.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let beacon = beacons[indexPath[1]]
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "standard", for: indexPath)
        let label = UILabel()
        label.text = String(beacon.period)
        label.sizeToFit()
        label.backgroundColor = UIColor.green
        cell.contentView.addSubview(label)
        return cell
    }
    
    
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
    
    override func viewDidAppear(_ animated: Bool) {
        // check /tmp for current.cb
        if let b = CryptoBeacon(json: FileManager.default.contents(atPath: tmpBeaconPath())) {
            beingVerified = b
            presenceVerification()
        } // else there is no cryptobeacon in range
    }
    
    func presenceVerification() {
        // display an alert asking if the user wants to provide biometric verification
        // if the alert is still being displayed after 30 seconds, then remove the alert
        var authError: NSError?
        let myContext = LAContext()
        if myContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
            let alert = UIAlertController(title: "Verify your presence", message: "You must provide biometric verification in the next 60 seconds", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "Verify", style: UIAlertActionStyle.default, handler: { action in
                // do biometric verification
                let myLocalizedReasonString = "Verify that you are present in class"
                myContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: myLocalizedReasonString) { success, evaluateError in
                    if success {
                        // User authenticated successfully, take appropriate action
                        APIWrapper.sharedInstance.signIn(hash: (self.beingVerified?.hash)!)
                        // delete the other hashes for current period
                        // don't set beingVerified to nil yet because there might be connection error
                    } else {
                        // User did not authenticate successfully, look at error and take appropriate action
                    }
                }
            }))
            DispatchQueue.main.async() {
                self.present(alert, animated: true, completion: nil)
            }
        } else {
            // device does not offer biometric verification, use password instead
            print("asking for password since no biometry")
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
