//
//  JoinPopoverViewController.swift
//  CoPaint
//
//  Created by 张睿杰 on 2020/9/5.
//  Copyright © 2020 张睿杰. All rights reserved.
//

import UIKit

class JoinPopoverViewController: UIViewController {
    
    @IBOutlet weak var codeField: UITextField!
    
    @IBAction func joinTapped(_ sender: Any) {
        if let room = codeField.text {
            let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PaintViewController") as! PaintViewController
            controller.room = Int(room)
            controller.modalPresentationStyle = .fullScreen
            print(Int(room))
            self.present(controller, animated: false, completion: nil)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
