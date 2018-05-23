//
//  ViewController.swift
//  Beacon Attendance
//
//  Created by Andrew Burford on 5/21/18.
//  Copyright © 2018 Andrew Burford. All rights reserved.
//

import UIKit

class LoginViewController: UIViewController {

    @IBOutlet weak var userField: UITextField!
    @IBOutlet weak var passField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    @IBAction func logInPressed(_ sender: Any) {
        let session = APIWrapper.sharedInstance
        do {
            try session.authenticate(user: userField.text!, pass: passField.text!)
            session.identifier = "logged in"
            NSLog("session hash:", session.identifier)
            self.performSegue(withIdentifier: "toHomeView", sender: self)
        } catch AuthError.credentialError(let msg) {
            NSLog("credential error")
            basicAlert(title: "Authentication Error", msg: msg, dismiss: "Okay")
        } catch AuthError.connectionError(let msg) {
            NSLog("connection error")
        } catch AuthError.keychainError(let msg){
            NSLog("keychain error:", msg)
            basicAlert(title: "Internal Error", msg: "Something went wrong with your keychain. Please contact developers if error persists", dismiss: "Okay")
        } catch {
            
        }
    }
    
    func basicAlert(title: String, msg: String, dismiss: String) {
        let alert = UIAlertController(title: title, message: msg, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: dismiss, style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

