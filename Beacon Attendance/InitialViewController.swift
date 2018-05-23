//
//  InitialViewController.swift
//  Beacon Attendance
//
//  Created by Andrew Burford on 5/22/18.
//  Copyright © 2018 Andrew Burford. All rights reserved.
//

import UIKit

class InitialViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let session = APIWrapper.sharedInstance

        if session.auth_token != nil {
//            auth_token was stored in the keychain, proceed to HomeView
            DispatchQueue.main.async() {
                [unowned self] in
                self.performSegue(withIdentifier: "toHomeView", sender: self)
            }
        } else {
//            not sure why we need this since we ARE on the main thread but it doesn't work otherwise
            DispatchQueue.main.async() {
                [unowned self] in
                self.performSegue(withIdentifier: "toLoginView", sender: self)
            }
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
