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
            NSLog("sending to home view")
            self.performSegue(withIdentifier: "toHomeView", sender: self)
        } catch AuthError.credentialError(let msg) {
            // display alert with msg
        } catch AuthError.connectionError(let msg) {
            // render a retry option
        } catch {
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

