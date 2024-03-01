//
//  MetalVC.swift
//  PanSwift
//
//  Created by Pan on 2021/9/15.
//

import UIKit
import Combine
import CombineDataSources
import CombineCocoa
import SnapKit
import Flutter

class JSONCoder {
    @Published public var functionList: Array<Function> = Array()
    @Published public var errorMessage: String?
}

struct Function: Codable, Equatable, Hashable {
    let vcName : String
    let title: String
    
    init(vcName: String, title: String) {
        self.vcName = vcName
        self.title = title
    }
}

class MetalVC: UIViewController {
    
    // MARK: - Property
    lazy var tableView: UITableView = {
        let tableView = UITableView()
        self.view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "UITableViewCell")
        tableView.separatorStyle = .none
        if #available(iOS 11.0, *) {
            tableView.contentInsetAdjustmentBehavior = .never
        }
        return tableView
    }()
    
    let dataSource: JSONCoder = JSONCoder()
    var cancellables = Set<AnyCancellable>()

    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        if #available(iOS 15.0, *) {
            let navBarAppearance = UINavigationBarAppearance()
            navBarAppearance.configureWithOpaqueBackground()
            navBarAppearance.backgroundColor = UIColor.white
            
            navigationController?.navigationBar.standardAppearance = navBarAppearance
            navigationController?.navigationBar.scrollEdgeAppearance = navBarAppearance
        }
        
        bindViews()
        
        dataSource.functionList.append(Function(vcName: "MetalHSVVC", title: "Flutter"))
        dataSource.functionList.append(Function(vcName: "MetalBasicOneVC", title: "加载系统模型"))
        dataSource.functionList.append(Function(vcName: "MetalBasicTwoVC", title: "加载本地模型"))
        dataSource.functionList.append(Function(vcName: "MetalBasicThreeVC", title: "绘制矩形"))
        dataSource.functionList.append(Function(vcName: "MetalLightVC", title: "灯光"))
        dataSource.functionList.append(Function(vcName: "MetalLoadImageVC", title: "加载图片"))
        dataSource.functionList.append(Function(vcName: "MetalRenderImageVC", title: "Lut图片滤镜"))
        dataSource.functionList.append(Function(vcName: "MetalCameraVC", title: "相机预览"))
        dataSource.functionList.append(Function(vcName: "MetalRenderCameraVC", title: "相机滤镜"))
        dataSource.functionList.append(Function(vcName: "MetalLutObjCameraVC", title: "Lut滤镜封装"))
        dataSource.functionList.append(Function(vcName: "MetalMultiCameraVC", title: "多镜头相机"))
        dataSource.functionList.append(Function(vcName: "MetalDepthCameraVC", title: "深度相机"))
        dataSource.functionList.append(Function(vcName: "MetalFilterChainVC", title: "滤镜链"))
        dataSource.functionList.append(Function(vcName: "MetalColorCoordinateVC", title: "色坐标"))
        dataSource.functionList.append(Function(vcName: "MetalHSIVC", title: "HSI"))
        dataSource.functionList.append(Function(vcName: "MetalHSVVC", title: "HSV"))
    }
    
    private func bindViews() {
        dataSource
            .$functionList
            .bind(subscriber: tableView.rowsSubscriber(cellIdentifier: "UITableViewCell", cellType: UITableViewCell.self, cellConfig: { (cell, indexPath, data) in
                cell.textLabel?.text = data.title
            }))
            .store(in: &cancellables)
        
        tableView
            .didSelectRowPublisher
            .sink { [weak self] (indexPath) in
                guard let strongSelf = self else { return }
                if indexPath.row == 0 {
                    strongSelf.jumpToFlutter()
                } else {
                    strongSelf.jumpToVC(classModel: strongSelf.dataSource.functionList[indexPath.row])
                }
                
            }
            .store(in: &cancellables)
    }
    
    func jumpToVC(classModel: Function) {
        guard let spaceName = Bundle.main.infoDictionary!["CFBundleExecutable"] as? String else {
            print("没有获取到命名空间")
            return
        }
        
        let vcClass: AnyClass? = NSClassFromString(spaceName + "." + classModel.vcName)
        
        guard let classType = vcClass as? UIViewController.Type else {
            print("不是控制器类型")
            return
        }

        let vc = classType.init()
        vc.title = classModel.title

        navigationController?.pushViewController(vc, animated: true)
    }
    
    /// 跳转到Flutter页面
    func jumpToFlutter() {
        let flutterEngine = (UIApplication.shared.delegate as! AppDelegate).flutterEngine
        let flutterViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
        navigationController?.pushViewController(flutterViewController, animated: true)
    }
    
}
