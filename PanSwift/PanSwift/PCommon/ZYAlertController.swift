//
//  ZYAlertController.swift
//  PanSwift
//
//  Created by Pan on 2022/10/9.
//

import UIKit

/// 蒙板样式
public enum ZYAlertMaskStyle: Int {
    case black = 0  //  默认黑色.透明度0.8
    case clear = 1  //  透明
}

public enum ZYAlertControllerStyle: Int {
    case actionSheet = 0
    case alert = 1
}

public class ZYAlertController: UIViewController {
    
    // MARK: - Property
    
    /// 背景蒙板
    public var backgroundView: UIView!
    
    /// 蒙板样式
    public var maskMode: ZYAlertMaskStyle = .black
    
    /// alert视图
    public var alertView: UIView?
    
    // MARK: - Life Cycle
    
    public required init?(coder: NSCoder) {
        super .init(coder: coder)
    }
    
    public func viewDidLoad() async {
        super.viewDidLoad()

        await withTaskGroup(of: Data.self, body: { taskGroup in
            
        })
    }
    
    func save() async -> String {
        outer: for i in 1...4 {
            if i == 2 {
                continue outer
            }
            
            if i == 3 {
                break outer
            }
            
            print("i = \(i)")
        }
        
        return ""
    }

}
