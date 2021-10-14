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

public let kSafaArea = UIApplication.shared.delegate?.window??.safeAreaInsets ?? UIEdgeInsets.zero

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
        
        bindViews()
        
        dataSource.functionList.append(Function(vcName: "MetalBasicOneVC", title: "MetalBasicOne"))
        dataSource.functionList.append(Function(vcName: "MetalBasicTwoVC", title: "MetalBasicTwo"))
        dataSource.functionList.append(Function(vcName: "MetalBasicThreeVC", title: "MetalBasicThree"))
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
                strongSelf.jumpToVC(classModel: strongSelf.dataSource.functionList[indexPath.row])
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
    
}
