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
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    @IBAction func logInPressed(_ sender: Any) {
        let session = APIWrapper.sharedInstance
        session.authenticate(user: userField.text!, pass: passField.text!, delegate: self)
        loadingIndicator.isHidden = false
    }
    
    func loginResponse(error: APIError?) {
        DispatchQueue.main.async {
            self.loadingIndicator.isHidden = true
        }
        if let error = error {
            switch error {
            case .connectionError(let msg):
                basicAlert(title: msg, msg: "Please try again", dismiss: "Okay", delegate: self)
                break
            case .credentialError:
                basicAlert(title: "Username/password incorrect", msg: "Please try again", dismiss: "Okay", delegate: self)
                break
            case .keychainError:
                basicAlert(title: "Internal Error", msg: "Something went wrong with your keychain. Please contact developers if error persists", dismiss: "Okay", delegate: self)
                break
            case .serverError:
                basicAlert(title: "Server Error", msg: "The server returned an error. Please contact developers if error persists.", dismiss: "Okay", delegate: self)
                break
            }
        } else {
            DispatchQueue.main.async() {
                self.performSegue(withIdentifier: "toHomeView", sender: self)
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

