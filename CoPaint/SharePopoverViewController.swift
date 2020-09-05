//
//  SharePopoverViewController.swift
//  CoPaint
//
//  Created by 张睿杰 on 2020/9/5.
//  Copyright © 2020 张睿杰. All rights reserved.
//

import UIKit

class SharePopoverViewController: UIViewController {

    var roomId: Int?
    @IBOutlet weak var roomLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let text = roomId {
            roomLabel.text = String(text)
        }
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
