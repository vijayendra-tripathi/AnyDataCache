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
        var messageDisplayed = false
        if let dataKey = passcodeView.text {
            DataCache.sharedInstance.getData(dataKey: dataKey) { [weak self] data in
                if let messageData = data?.data {
                    if let message = String(data: messageData, encoding: .utf8) {
                        self?.noteView.text = message
                        messageDisplayed = true
                    }
                }
                if !messageDisplayed {
                    self?.showMessage(title: "Error", message: "No message found for your data key.")
                }
            }
        }
    }
    
    
    @IBAction func saveNote(_ sender: Any) {
        var messageSaved = false
        if let dataKey = passcodeView.text {
            if let noteData = noteView.text.data(using: .utf8) {
                DataCache.sharedInstance.addData(dataKey: dataKey, data: noteData)
                messageSaved = true
            }
        }
        if messageSaved {
            showMessage(title: "Yes!", message: "Your message is saved.")
        }
        else {
            showMessage(title: "Error", message: "Sorry message could not be saved.")
        }
    }
    
    
    @IBAction func clearViews(_ sender: Any) {
        noteView.text = ""
        passcodeView.text = ""
    }
    
    
    func showMessage(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        self.show(alert, sender: nil)
    }

}


