import UIKit

/// JoystickDelegate 协议定义了虚拟摇杆的回调方法
protocol JoystickDelegate: AnyObject {
    /// 当摇杆移动时调用
    /// - Parameters:
    ///   - angle: 移动的角度（0-360度，0度指向右侧，顺时针增加）
    ///   - strength: 移动的力度（0-1，表示到达最大移动范围的比例）
    func joystickDidMove(angle: CGFloat, strength: CGFloat)
    
    /// 当摇杆释放，回到中心位置时调用
    func joystickDidEnd()
}

/// JoystickView 是一个自定义的虚拟摇杆控件
/// 提供了一个可以全方向移动的摇杆界面，支持触摸控制和力度检测
class JoystickView: UIView {
    
    // MARK: - Properties
    /// 底座的直径大小
    private let baseSize: CGFloat = 100
    /// 摇杆的直径大小
    private let stickSize: CGFloat = 50
    /// 底座视图
    private var baseView: UIView!
    /// 摇杆视图
    private var stickView: UIView!
    /// 是否正在追踪触摸
    private var tracking = false
    /// 摇杆可移动的最大半径
    private var movableRange: CGFloat = 0
    /// 初始触摸位置
    private var initialStickPosition: CGPoint = .zero
    /// 动画时长
    private let animationDuration: TimeInterval = 0.15
    
    /// 代理对象，用于接收摇杆的移动事件
    weak var delegate: JoystickDelegate?
    
    // MARK: - Initialization
    /// 使用代码初始化时调用
    /// - Parameter frame: 控件的frame
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupJoystick()
    }
    
    /// 使用Storyboard或xib初始化时调用
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupJoystick()
    }
    
    // MARK: - Setup
    /// 初始化摇杆界面
    private func setupJoystick() {
        // 设置底座视图 - 一个半透明的灰色圆形
        baseView = UIView(frame: CGRect(x: 0, y: 0, width: baseSize, height: baseSize))
        baseView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        baseView.backgroundColor = UIColor.gray.withAlphaComponent(0.3)
        baseView.layer.cornerRadius = baseSize / 2
        baseView.layer.borderWidth = 1.0
        baseView.layer.borderColor = UIColor.gray.withAlphaComponent(0.5).cgColor
        addSubview(baseView)
        
        // 设置摇杆视图 - 一个深灰色的小圆形
        stickView = UIView(frame: CGRect(x: 0, y: 0, width: stickSize, height: stickSize))
        stickView.center = baseView.center
        stickView.backgroundColor = UIColor.darkGray.withAlphaComponent(0.8)
        stickView.layer.cornerRadius = stickSize / 2
        stickView.layer.shadowColor = UIColor.black.cgColor
        stickView.layer.shadowOffset = CGSize(width: 0, height: 2)
        stickView.layer.shadowOpacity = 0.3
        stickView.layer.shadowRadius = 3
        addSubview(stickView)
        
        // 计算摇杆可移动的最大半径（底座半径减去摇杆半径）
        movableRange = (baseSize - stickSize) / 2
        
        // 启用多点触摸
        isMultipleTouchEnabled = false
        
        // 保存初始位置
        initialStickPosition = stickView.center
    }
    
    // MARK: - Touch Handling
    /// 处理触摸开始事件
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // 只要触摸在底座范围内就开始追踪
        if baseView.frame.contains(location) {
            tracking = true
            
            // 直接移动摇杆到触摸位置
            moveStick(to: location)
            
            // 添加触感反馈
            generateTouchFeedback()
        }
    }
    
    /// 处理触摸移动事件
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard tracking, let touch = touches.first else { return }
        let location = touch.location(in: self)
        moveStick(to: location)
    }
    
    /// 处理触摸结束事件
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetStickPosition()
    }
    
    /// 处理触摸取消事件（如来电等系统中断）
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetStickPosition()
    }
    
    // MARK: - Helper Methods
    /// 移动摇杆到指定位置
    private func moveStick(to location: CGPoint) {
        let baseCenter = baseView.center
        let delta = CGPoint(x: location.x - baseCenter.x, y: location.y - baseCenter.y)
        var distance = sqrt(pow(delta.x, 2) + pow(delta.y, 2))
        let angle = atan2(delta.y, delta.x)
        
        // 限制摇杆移动范围在最大半径内
        if distance > movableRange {
            distance = movableRange
        }
        
        // 使用 CADisplayLink 或 UIView.animate 实现更流畅的动画
        UIView.animate(withDuration: 0.1, delay: 0, options: [.allowUserInteraction, .curveEaseOut], animations: {
            // 根据角度和距离计算摇杆的新位置
            let newX = baseCenter.x + distance * cos(angle)
            let newY = baseCenter.y + distance * sin(angle)
            self.stickView.center = CGPoint(x: newX, y: newY)
        })
        
        // 计算移动强度（0-1）
        let strength = distance / movableRange
        
        // 将弧度转换为角度（0-360度）
        let degrees = (angle * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
        
        // 通知代理摇杆移动事件
        delegate?.joystickDidMove(angle: degrees, strength: strength)
    }
    
    /// 重置摇杆位置到中心
    private func resetStickPosition() {
        tracking = false
        
        // 使用弹性动画平滑地将摇杆返回中心位置
        UIView.animate(withDuration: animationDuration,
                      delay: 0,
                      usingSpringWithDamping: 0.7,
                      initialSpringVelocity: 0.5,
                      options: .curveEaseOut,
                      animations: {
            self.stickView.center = self.baseView.center
        })
        
        // 通知代理摇杆已回到中心位置
        delegate?.joystickDidEnd()
    }
    
    /// 生成触感反馈
    private func generateTouchFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
} 