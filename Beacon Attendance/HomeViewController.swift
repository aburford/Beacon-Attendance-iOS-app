
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
    @IBOutlet weak var unsyncedCV: UICollectionView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var retryBtn: UIButton!
    @IBOutlet weak var syncLbl: UILabel!
    @IBOutlet weak var periodsLbl: UILabel!
    
    let signingInIndicator = UIActivityIndicatorView()
    
    var beingVerified: CryptoBeacon? = nil
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == periodsCV {
            return FileWrapper.shared.periods().count
        } else {
            return FileWrapper.shared.getVerified().count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "standard", for: indexPath)
        for view in cell.contentView.subviews {
            view.removeFromSuperview()
        }
        let period: Int
        if collectionView == periodsCV {
            period = FileWrapper.shared.periods()[indexPath[1]]
        } else {
            period = FileWrapper.shared.getVerified()[indexPath[1]].period
        }
        let btn = UIButton()
        btn.frame.size = cell.frame.size
        btn.frame.origin = CGPoint(x: 0, y: 0)
        btn.setTitle("Period \(period)", for: .normal)
        btn.setTitleColor(.black, for: .normal)
        btn.titleLabel!.textAlignment = .center
        btn.backgroundColor = UIColor.clear
        btn.titleLabel!.font = UIFont.systemFont(ofSize: 16)
        btn.addTarget(self, action: #selector(HomeViewController.periodCellPressed(_:)), for: .touchUpInside)
        cell.contentView.addSubview(btn)
        cell.layer.cornerRadius = 10
        return cell
    }
    
    @IBAction func logoutPressed(_ sender: Any) {
        // stop listening for all hashes (including static) so no weird stuff happens
        let delegate = UIApplication.shared.delegate as! AppDelegate
        delegate.removeBeaconsForPeriod(nil, earlierPeriods: nil)
        do {
            try APIWrapper.sharedInstance.logout()
            performSegue(withIdentifier: "toLoginView", sender: self)
        } catch {
            // alert user that something went wrong
        }
    }
    
    @IBAction func retrySync(_ sender: Any) {
        var hashes: [Hashes] = []
        var oldBeacons: [CryptoBeacon] = []
        for b in FileWrapper.shared.getVerified() {
            if b.date == todayStr() {
                hashes.append(b.hashes)
            } else {
                oldBeacons.append(b)
            }
        }
        if oldBeacons.count > 0 {
            var msg = ""
            for b in oldBeacons {
                msg += "Period \(b.period) on \(betterDate(date: b.date))\n"
            }
            let alert = UIAlertController.init(title: "Sync failure", message: "The following attendance records could not be synced because they are a day old:\n\(msg)", preferredStyle: .alert)
            FileWrapper.shared.removeVerified(oldBeacons)
            alert.addAction(UIAlertAction(title: "Okay", style: .cancel, handler: { action in
                self.retrySignIn(hashes: hashes)
            }))
            present(alert, animated: true)
        } else {
            retrySignIn(hashes: hashes)
        }
    }
    
    @objc func periodCellPressed(_ sender: Any) {
        let cell = periodsCV.visibleCells.first { (cell) -> Bool in
            (cell.contentView.subviews.first?.isEqual(sender))!
        }
        let cellPeriod = FileWrapper.shared.periods()[periodsCV.indexPath(for: cell!)![1]]
        let alert = UIAlertController(title: "You currently do not appear to be in your period \(cellPeriod) class", message: "You will be notified when you are detected to be present. If you opt to sign in manually, the app will stop monitoring your location for this period.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Sign In Manually", style: UIAlertActionStyle.default, handler: { action in
            // stop monitoring for other hashes for that period
            print("student opted for manual sign in, stopMonitoring for each beacon for that period")
            let delegate = UIApplication.shared.delegate as! AppDelegate
            delegate.removeBeaconsForPeriod(cellPeriod, earlierPeriods: false)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    func reloadPeriodsCV() {
        // it takes a small amount of time for CLLocationManager to update .monitoredRegions after .startMonitoring is called
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            // if we are just monitoring for static
            if appDelegate.locationManager.monitoredRegions.count == 1 {
                self.periodsLbl.text = "No more classes to sign in to today"
            } else {
                self.periodsLbl.text = "Classes you haven't signed in to:"
            }
            print("calling periodsCV.reloadData()")
            self.periodsCV.reloadData()
        }
    }
    
    func betterDate(date: String) -> String {
        let betterDate = date.split(separator: "-")
        return "\(betterDate[1])/\(betterDate[2])"
    }
    
    func retrySignIn(hashes: [Hashes]) {
        if hashes.count > 0 {
            APIWrapper.sharedInstance.signIn(hashes: hashes, delegate: self)
            activityIndicator.isHidden = false
            retryBtn.isHidden = true
        } else {
            updateUnsynced()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let session = APIWrapper.sharedInstance
        if session.auth_token != nil {
            print("auth token found: \(session.auth_token!)")
            DispatchQueue.main.async() {
                self.view.isHidden = false
                let screenSize = UIScreen.main.bounds.size
                self.signingInIndicator.bounds.size = screenSize
                self.signingInIndicator.center = CGPoint(x: screenSize.width / 2, y: screenSize.height / 2)
                self.signingInIndicator.backgroundColor = UIColor.darkGray.withAlphaComponent(0.7)
                self.signingInIndicator.hidesWhenStopped = true
//                self.signingInIndicator.startAnimating()
                self.signingInIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.whiteLarge
                self.view.addSubview(self.signingInIndicator)
            }
            self.reloadPeriodsCV()
            self.updateUnsynced()
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
    
    func checkForNewBeacon() {
        // check /tmp for current.cb
        if UserDefaults.standard.object(forKey: "lastSyncDate") as? String != todayStr() {
            // not sure if we're already in main thread
            DispatchQueue.main.async {
                let delegate = UIApplication.shared.delegate as! AppDelegate
                delegate.removeBeaconsForPeriod(nil, earlierPeriods: nil)
                APIWrapper.sharedInstance.requestBeacons(delegate: delegate)
                // TODO: we could show loading indicator?
            }
        } else {
            print("checking for new beacons")
            if let b = CryptoBeacon(json: FileManager.default.contents(atPath: tmpBeaconPath())) {
                beingVerified = b
                presenceVerification()
            } // else there is no cryptobeacon in range
            reloadPeriodsCV()
            updateUnsynced()
        }
    }
    
    func updateUnsynced() {
        DispatchQueue.main.async {
            self.unsyncedCV.reloadData()
            if FileWrapper.shared.getVerified().count == 0 {
                self.retryBtn.isHidden = true
                self.syncLbl.text = "Everything is synced"
            } else {
                self.retryBtn.isHidden = false
                self.syncLbl.text = "Not yet synced with server:"
            }
            self.activityIndicator.isHidden = true
        }
    }
    
    func presenceVerification() {
        print("beginning presence verification for beacon: " + String(describing: beingVerified))
        // display an alert asking if the user wants to provide biometric verification
        // if the alert is still being displayed after 30 seconds, then remove the alert
        var authError: NSError?
        let myContext = LAContext()
        if myContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
            let alert = UIAlertController(title: "Verify your presence", message: "You must immediately provide biometric verification. If you opt to sign in manually, the app will stop monitoring your location for this period.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Verify", style: UIAlertActionStyle.default, handler: { action in
                self.doBiometricVerification()
            }))
            alert.addAction(manualSignIn())
            DispatchQueue.main.async() {
                self.present(alert, animated: true, completion: nil)
            }
        } else {
            // device does not offer biometric verification, use password instead
            print("asking for password since no biometry")
        }
    }
    
    func doBiometricVerification() {
        let myContext = LAContext()
        let myLocalizedReasonString = "Verify that you are present in class"
        myContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: myLocalizedReasonString) { success, evaluateError in
            self.handleLAEvaluation(success: success)
        }
    }
    
    func handleLAEvaluation(success: Bool) {
        // check /tmp in case they took to long and beacon no longer in range
        if let cb = CryptoBeacon(json: FileManager.default.contents(atPath: tmpBeaconPath())) {
            if cb.period == self.beingVerified!.period, cb.attendance_code == self.beingVerified!.attendance_code {
                // we could use cb.hash for the same result
                if success {
                    APIWrapper.sharedInstance.signIn(hashes: [self.beingVerified!.hashes], delegate: self)
                    DispatchQueue.main.async {
                        self.signingInIndicator.startAnimating()
                    }
                } else {
                    // user is still in range of a beacon with the same attendance_code as beingVerified, allow them to try again
                    let alert = UIAlertController(title: "Biometric Verification Failed", message: "You could not be verified as \(beingVerified!.attendance_code) for period \(beingVerified!.period)", preferredStyle: UIAlertControllerStyle.alert)
                    alert.addAction(UIAlertAction(title: "Try again", style: UIAlertActionStyle.default, handler: { action in
                        self.doBiometricVerification()
                    }))
                    alert.addAction(self.manualSignIn())
                    DispatchQueue.main.async {
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            } else {
                // user can no longer be signed in with that attendance code, but they can choose to be signed in with the new hash now being advertised
                let alertMsg: String = success ? "You took to long to verify that you were \(self.beingVerified!.attendance_code). However, you can now be marked \(cb.attendance_code) for period \(cb.period)" : "You took to long to verify that you were \(self.beingVerified!.attendance_code). However, you can now verify that you are \(cb.attendance_code) for period \(cb.period)"
                let alert = UIAlertController(title: "Too slow!", message: alertMsg, preferredStyle: UIAlertControllerStyle.alert)
                self.beingVerified = cb
                alert.addAction(manualSignIn())
                if success {
                    alert.addAction(UIAlertAction(title: "Continue", style: UIAlertActionStyle.default, handler: { action in
                        APIWrapper.sharedInstance.signIn(hashes: [self.beingVerified!.hashes], delegate: self)
                        DispatchQueue.main.async {
                            self.signingInIndicator.startAnimating()
                        }
                    }))
                } else {
                    alert.addAction(UIAlertAction(title: "Verify", style: UIAlertActionStyle.default, handler: { action in
                        self.doBiometricVerification()
                    }))
                }
                DispatchQueue.main.async {
                    self.present(alert, animated: true)
                }
            }
            // at this point, beingVerified will either be synced to server, or saved to be synced later
            // that means we can stop listening for beacons for beingVerified.period and earlier periods
            // and it means we should delete current.cb so that the user is not prompted to sign in twice
            if success {
                print("stopping monitoring for beacons for period \(self.beingVerified!.period)")
                DispatchQueue.main.async {
                    let delegate = UIApplication.shared.delegate as! AppDelegate
                    delegate.removeBeaconsForPeriod(self.beingVerified!.period, earlierPeriods: true)
                }
                try! FileManager.default.removeItem(atPath: tmpBeaconPath())
            }
        } else {
            // they took too long, current.cb no longer exists
            basicAlert(title: "Too slow!", msg: "You took too long to verify that you were \(self.beingVerified!.attendance_code) for period \(self.beingVerified!.period)", dismiss: "Okay", delegate: self)
            self.beingVerified = nil
            // at this point we could stop monitoring for beacons for beingVerified.period
            // but that will be cleaned up tomorrow anyway so meh
            // also, current.cb is already gone so we don't need to delete that
        }
    }
    
    func signedIn(error: APIError?) {
        print("signed in with error: " + String(describing: error))
        DispatchQueue.main.async {
            self.signingInIndicator.stopAnimating()
        }
        if let error = error {
            // save beingVerified to sync to server later
            switch error {
            case .connectionError(let title):
                basicAlert(title: title, msg: "Try again later", dismiss: "Okay", delegate: self)
                // save beingVerified for later
                // if beingVerified is nil because retrySync was called, nothing will happen
                let _ = FileWrapper.shared.saveVerified(cb: beingVerified)
            case .credentialError(let title):
                basicAlert(title: title, msg: "This shouldn't have happened. Try logging out and logging back in.", dismiss: "Okay", delegate: self)
            // don't delete current.cb so they can sign in after they log out and log back in
            case .serverError(let title):
                basicAlert(title: title, msg: "Failed to sync attendance with server. Please contact the developers.", dismiss: "Okay", delegate: self)
            default:
                break
            }
            beingVerified = nil
        } else {
            if beingVerified != nil {
                basicAlert(title: "Success!", msg: "You will be marked \(beingVerified!.attendance_code) for period \(beingVerified!.period)", dismiss: "Okay", delegate: self)
                beingVerified = nil
            } else {
                // retry sync button was pressed
                FileWrapper.shared.removeVerified(nil)
            }
        }
        updateUnsynced()
    }
    
    func manualSignIn() -> UIAlertAction {
        return UIAlertAction(title: "Sign In Manually", style: UIAlertActionStyle.default, handler: { action in
            // stop monitoring for other hashes for that period (copy pasted from manualSignin() b/c one variable had to be changed
            print("student opted for manual sign in, stopMonitoring for each beacon for that period")
            let delegate = UIApplication.shared.delegate as! AppDelegate
            delegate.removeBeaconsForPeriod(self.beingVerified!.period, earlierPeriods: false)
            self.beingVerified = nil
            try? FileManager.default.removeItem(atPath: tmpBeaconPath())
            self.reloadPeriodsCV()
        })
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
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
