//
//  MetalBasicVC.swift
//  PanSwift
//
//  Created by Pan on 2021/9/18.
//

import UIKit
import MetalKit

///主窗口
public let kMainWindow  = UIApplication.shared.delegate?.window
///主窗口frame
public let kMainScreenFrame = UIScreen.main.bounds
/// 屏幕的宽
public let kScreenWidth = UIScreen.main.bounds.width
/// 屏幕的高
public let kScreenHeight = UIScreen.main.bounds.height
/// 机型判断
public let isiPhoneX: Bool = (kScreenHeight == 812 ? true : false)
/// 导航栏高度
public let kNavHeight:CGFloat = (kScreenHeight >= 812 ? 88 : 64)
/// 状态栏高度
public let kStatusHeight:CGFloat = (kScreenHeight >= 812 ? 44 : 20)
/// tabbar高度
public let kTabBarHeight:CGFloat = (kScreenHeight >= 812 ? 83 : 49)
/// 安全区
public let kSafaArea = UIApplication.shared.delegate?.window??.safeAreaInsets ?? UIEdgeInsets.zero

class MetalBasicVC: UIViewController {
    
    // MARK: - Property
    var metalContext = PMetalContext()
    
    var mtkView: MTKView!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
        
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    func setupUI() {
        setupMTKView()
        
        let backBtn = UIButton(type: .custom)
        view.addSubview(backBtn)
        backBtn.snp.makeConstraints { make in
            make.left.equalTo(25)
            make.top.equalTo(kNavHeight + 10)
            make.size.equalTo(CGSize(width: 40, height: 40))
        }
        backBtn.setTitle("返回", for: .normal)
        backBtn.setTitleColor(.white, for: .normal)
        backBtn.addTarget(self, action: #selector(backBtnClick), for: .touchUpInside)
    }
    
    func setupMTKView() {
        let mtkView = MTKView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.width), device: metalContext.device)
        mtkView.center = CGPoint(x: view.frame.size.width / 2, y: view.frame.size.height / 2)
        mtkView.clearColor = MTLClearColor(red: 1, green: 1, blue: 0.8, alpha: 1)
//        view.layer.addSublayer(mtkView.layer)
        view.addSubview(mtkView)
        
        self.mtkView = mtkView
    }
    
    @objc func backBtnClick() {
        navigationController?.popViewController(animated: true)
    }

}
