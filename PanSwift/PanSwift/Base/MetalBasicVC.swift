//
//  MetalBasicVC.swift
//  PanSwift
//
//  Created by Pan on 2021/9/18.
//

import UIKit
import MetalKit

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
        let backBtn = UIButton(type: .custom)
        view.addSubview(backBtn)
        backBtn.snp.makeConstraints { make in
            make.left.top.equalTo(25)
            make.size.equalTo(CGSize(width: 40, height: 40))
        }
        backBtn.setTitle("返回", for: .normal)
        backBtn.setTitleColor(.white, for: .normal)
        backBtn.addTarget(self, action: #selector(backBtnClick), for: .touchUpInside)
        
        setupMTKView()
    }
    
    func setupMTKView() {
        let mtkView = MTKView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.width), device: metalContext.device)
        mtkView.center = CGPoint(x: view.frame.size.width / 2, y: view.frame.size.height / 2)
        mtkView.clearColor = MTLClearColor(red: 1, green: 1, blue: 0.8, alpha: 1)
        view.layer.addSublayer(mtkView.layer)
        
        self.mtkView = mtkView
    }
    
    @objc func backBtnClick() {
        navigationController?.popViewController(animated: true)
    }

}
