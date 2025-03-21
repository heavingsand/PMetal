//
//  JoystickViewController.swift
//  PanSwift
//
//  Created by Pan on 2022/10/8.
//

import UIKit

class JoystickViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        // 创建手柄视图
        let joystickView = JoystickView(frame: CGRect(x: 100, y: 100, width: 200, height: 200))
        view.addSubview(joystickView)
    }
    
}

