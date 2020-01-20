//
//  ViewController.swift
//  AnyDataCache
//
//  Created by vijayendra-tripathi on 01/19/2020.
//  Copyright (c) 2020 vijayendra-tripathi. All rights reserved.
//

import UIKit
import AnyDataCache

class ViewController: UIViewController {
    
    
    @IBOutlet weak var noteView: UITextView!
    @IBOutlet weak var passcodeView: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func readNote(_ sender: Any) {
        if let dataKey = passcodeView.text {
            
        }
    }
    
    
    @IBAction func saveNote(_ sender: Any) {
    }
    
    
    @IBAction func clearViews(_ sender: Any) {
    }
    
    
    func showMessage(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        self.show(alert, sender: nil)
    }

}

