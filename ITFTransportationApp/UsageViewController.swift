//
//  UsageViewController.swift
//  ITFTransportationApp
//
//  Created by Yasuko Namikawa on 2019/03/17.
//  Copyright © 2019年 Yasuko Namikawa. All rights reserved.
//

import UIKit

class UsageViewController: UIViewController,  UIScrollViewDelegate {
    
    @IBOutlet var scrollView :UIScrollView!
    
    @IBOutlet var header: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        header.frame = CGRect(x:0, y:0, width:scrollView.frame.width, height:94)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        header.frame = CGRect(x:0, y:0+scrollView.contentOffset.y, width:scrollView.frame.width, height:94)
    }
    
    @IBAction func toFirstView() {
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }

}
