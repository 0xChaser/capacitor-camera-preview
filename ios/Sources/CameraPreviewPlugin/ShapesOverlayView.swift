import UIKit

class ShapesOverlayView: UIView {
    var shapes: [UIView] = []
    private var activeShape: UIView?
    

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
        self.isUserInteractionEnabled = true
        self.isMultipleTouchEnabled = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        
        for shape in shapes.reversed() {
            let convertedPoint = shape.convert(point, from: self)
            if shape.bounds.contains(convertedPoint) {
                return shape
            }
            if let handle = shape.viewWithTag(999) {
                let handlePoint = handle.convert(point, from: self)
                if handle.bounds.contains(handlePoint) {
                    return handle
                }
            }
            if let deleteBtn = shape.viewWithTag(998) {
                let btnPoint = deleteBtn.convert(point, from: self)
                if deleteBtn.bounds.contains(btnPoint) {
                    return deleteBtn
                }
            }
        }
        return nil
    }
    
    
    
    struct ShapeData: Codable {
        let type: String
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        let rotation: CGFloat
        let color: String
    }
    
    struct OverlayData: Codable {
        let shapes: [ShapeData]
    }
    
    func getOverlayData() -> String? {
        var shapesData: [ShapeData] = []
        
        for shape in shapes {
            guard let shapeView = shape as? ShapeView else { continue }
            
            let rotation = atan2(shapeView.transform.b, shapeView.transform.a)
            
            let center = shapeView.center
            let size = shapeView.bounds.size
            let x = center.x - size.width / 2
            let y = center.y - size.height / 2
            
            let data = ShapeData(
                type: shapeView.type,
                x: x,
                y: y,
                width: size.width,
                height: size.height,
                rotation: rotation,
                color: shapeView.hexColor
            )
            shapesData.append(data)
        }
        
        let overlayData = OverlayData(shapes: shapesData)
        
        do {
            let jsonData = try JSONEncoder().encode(overlayData)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("Error encoding overlay data: \(error)")
            return nil
        }
    }
    
    func loadOverlayData(_ json: String) {
        guard let data = json.data(using: .utf8) else { return }
        
        do {
            let overlayData = try JSONDecoder().decode(OverlayData.self, from: data)
            
            
            removeAllShapes()
            
            
            for shapeData in overlayData.shapes {
                let color = color(from: shapeData.color)
                addShape(type: shapeData.type, color: color, frame: CGRect(x: shapeData.x, y: shapeData.y, width: shapeData.width, height: shapeData.height), rotation: shapeData.rotation)
            }
            
        } catch {
            print("Error decoding overlay data: \(error)")
        }
    }
    
    func color(from hex: String) -> UIColor {
        var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if (cString.hasPrefix("#")) { cString.remove(at: cString.startIndex) }
        if ((cString.count) != 6) { return UIColor.gray }
        var rgbValue:UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)
        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }

    func addShape(type: String, color: UIColor, frame: CGRect? = nil, rotation: CGFloat = 0) {
        let size: CGFloat = 100
        let centerX = self.bounds.width / 2 - size / 2
        let centerY = self.bounds.height / 2 - size / 2
        let defaultFrame = CGRect(x: centerX, y: centerY, width: size, height: size)
        
        let shapeFrame = frame ?? defaultFrame
        let shapeView: ShapeView
        
        let hexColor = toHexString(color: color)
        
        if type == "arrow" {
            shapeView = ArrowView(frame: shapeFrame)
            (shapeView as? ArrowView)?.color = color
        } else {
            shapeView = RectangleView(frame: shapeFrame)
            shapeView.layer.borderColor = color.cgColor
        }
        
        shapeView.type = type
        shapeView.hexColor = hexColor
        
        if rotation != 0 {
            shapeView.transform = CGAffineTransform(rotationAngle: rotation)
        }
        
        setupShapeGestures(shapeView)
        self.addSubview(shapeView)
        shapes.append(shapeView)
    }
    
    func toHexString(color: UIColor) -> String {
        var r:CGFloat = 0
        var g:CGFloat = 0
        var b:CGFloat = 0
        var a:CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb:Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        return String(format:"#%06x", rgb)
    }
    
    func setupShapeGestures(_ shapeView: UIView) {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        shapeView.addGestureRecognizer(panGesture)
        
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        shapeView.addGestureRecognizer(pinchGesture)
        
        let rotateGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotate(_:)))
        shapeView.addGestureRecognizer(rotateGesture)
        
        shapeView.isUserInteractionEnabled = true
        shapeView.isMultipleTouchEnabled = true
        
        let handleSize: CGFloat = 30
        let resizeHandle = UIView(frame: CGRect(x: shapeView.bounds.width - handleSize, y: shapeView.bounds.height - handleSize, width: handleSize, height: handleSize))
        resizeHandle.backgroundColor = UIColor.white.withAlphaComponent(0.8)
        resizeHandle.layer.cornerRadius = handleSize / 2
        resizeHandle.tag = 999
        resizeHandle.isUserInteractionEnabled = true
        
        let resizePan = UIPanGestureRecognizer(target: self, action: #selector(handleResize(_:)))
        resizeHandle.addGestureRecognizer(resizePan)
        shapeView.addSubview(resizeHandle)
        
        let deleteBtnSize: CGFloat = 24
        let deleteBtn = UIButton(frame: CGRect(x: -12, y: -12, width: deleteBtnSize, height: deleteBtnSize))
        deleteBtn.backgroundColor = .red
        deleteBtn.layer.cornerRadius = deleteBtnSize / 2
        deleteBtn.setTitle("×", for: .normal)
        deleteBtn.setTitleColor(.white, for: .normal)
        deleteBtn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        deleteBtn.tag = 998
        deleteBtn.addTarget(self, action: #selector(deleteShape(_:)), for: .touchUpInside)
        shapeView.addSubview(deleteBtn)
        
        shapeView.clipsToBounds = false
    }

    class ShapeView: UIView {
        var type: String = "rectangle"
        var hexColor: String = "#FFFFFF"
    }

    class RectangleView: ShapeView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            self.backgroundColor = .clear
            self.layer.borderWidth = 4
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    }

    class ArrowView: ShapeView {
        var color: UIColor = .red {
            didSet { setNeedsDisplay() }
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            self.contentMode = .redraw
            self.backgroundColor = .clear
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        
        override func draw(_ rect: CGRect) {
            guard let context = UIGraphicsGetCurrentContext() else { return }
            let width = rect.width
            let height = rect.height
            let shaftWidth = height * 0.3
            let headLength = width * 0.4
            
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: (height - shaftWidth) / 2))
            path.addLine(to: CGPoint(x: width - headLength, y: (height - shaftWidth) / 2))
            path.addLine(to: CGPoint(x: width - headLength, y: 0))
            path.addLine(to: CGPoint(x: width, y: height / 2))
            path.addLine(to: CGPoint(x: width - headLength, y: height))
            path.addLine(to: CGPoint(x: width - headLength, y: (height + shaftWidth) / 2))
            path.addLine(to: CGPoint(x: 0, y: (height + shaftWidth) / 2))
            path.close()
            
            context.setFillColor(color.cgColor)
            context.addPath(path.cgPath)
            context.fillPath()
            
             context.setStrokeColor(UIColor.white.cgColor)
             context.setLineWidth(2)
             context.addPath(path.cgPath)
             context.strokePath()
        }
    }
    
    @objc func deleteShape(_ sender: UIButton) {
        guard let shapeView = sender.superview else { return }
        shapeView.removeFromSuperview()
        if let index = shapes.firstIndex(of: shapeView) {
            shapes.remove(at: index)
        }
    }
    
    @objc func handleRotate(_ gesture: UIRotationGestureRecognizer) {
        guard let shapeView = gesture.view else { return }
        
        if gesture.state == .began || gesture.state == .changed {
            shapeView.transform = shapeView.transform.rotated(by: gesture.rotation)
            gesture.rotation = 0
        }
        
        if gesture.state == .began {
            self.bringSubviewToFront(shapeView)
            activeShape = shapeView
        }
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let shapeView = gesture.view else { return }
        let translation = gesture.translation(in: self)
        
        shapeView.center = CGPoint(x: shapeView.center.x + translation.x, y: shapeView.center.y + translation.y)
        
        gesture.setTranslation(.zero, in: self)
        
        if gesture.state == .began {
            self.bringSubviewToFront(shapeView)
            activeShape = shapeView
        }
    }
    
    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let shapeView = gesture.view else { return }
        
        if gesture.state == .began || gesture.state == .changed {
            let scale = gesture.scale
            let newWidth = shapeView.bounds.width * scale
            let newHeight = shapeView.bounds.height * scale
            
            let minSize: CGFloat = 50
            let maxSize: CGFloat = 300
            
            if newWidth >= minSize && newWidth <= maxSize && newHeight >= minSize && newHeight <= maxSize {
                let center = shapeView.center
                shapeView.bounds = CGRect(x: 0, y: 0, width: newWidth, height: newHeight)
                shapeView.center = center
                
                if let handle = shapeView.viewWithTag(999) {
                    let handleSize: CGFloat = 30
                    handle.frame = CGRect(x: newWidth - handleSize, y: newHeight - handleSize, width: handleSize, height: handleSize)
                }
            }
            
            gesture.scale = 1.0
        }
        
        if gesture.state == .began {
            self.bringSubviewToFront(shapeView)
        }
    }
    
    @objc func handleResize(_ gesture: UIPanGestureRecognizer) {
        guard let handle = gesture.view,
              let shapeView = handle.superview else { return }
        
        let translation = gesture.translation(in: shapeView)
        
        let newWidth = max(50, min(300, shapeView.bounds.width + translation.x))
        let newHeight = max(50, min(300, shapeView.bounds.height + translation.y))
        
        shapeView.bounds = CGRect(x: 0, y: 0, width: newWidth, height: newHeight)
        
        let handleSize: CGFloat = 30
        handle.center = CGPoint(x: newWidth - handleSize/2, y: newHeight - handleSize/2)
        handle.bounds = CGRect(x: 0, y: 0, width: handleSize, height: handleSize)
        
        gesture.setTranslation(.zero, in: shapeView)
        
        if gesture.state == .began {
            self.bringSubviewToFront(shapeView)
        }
        
        shapeView.setNeedsDisplay()
    }
    
    func rotateShapes(currentImageSize: CGSize, viewSize: CGSize) {
        let oldScale = max(viewSize.width / currentImageSize.width, viewSize.height / currentImageSize.height)
        let oldOffsetX = (viewSize.width - currentImageSize.width * oldScale) / 2
        let oldOffsetY = (viewSize.height - currentImageSize.height * oldScale) / 2
        
        let newImageSize = CGSize(width: currentImageSize.height, height: currentImageSize.width)
        
        let newScale = max(viewSize.width / newImageSize.width, viewSize.height / newImageSize.height)
        let newOffsetX = (viewSize.width - newImageSize.width * newScale) / 2
        let newOffsetY = (viewSize.height - newImageSize.height * newScale) / 2
        
        for shape in shapes {
            let cx = shape.center.x
            let cy = shape.center.y
            
            let oldImgX = (cx - oldOffsetX) / oldScale
            let oldImgY = (cy - oldOffsetY) / oldScale
            
            let newImgX = currentImageSize.height - oldImgY
            let newImgY = oldImgX
            
            let newCx = newOffsetX + newImgX * newScale
            let newCy = newOffsetY + newImgY * newScale
            
            shape.center = CGPoint(x: newCx, y: newCy)
            shape.transform = shape.transform.rotated(by: .pi / 2)
        }
        
    }
    
    func removeAllShapes() {
        for shape in shapes {
            shape.removeFromSuperview()
        }
        shapes.removeAll()
    }
}
