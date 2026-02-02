import Foundation
import Capacitor
import AVFoundation

@objc(CameraPreview)
public class CameraPreview: CAPPlugin, CAPBridgedPlugin {

    public let identifier = "CameraPreviewPlugin"
    public let jsName = "CameraPreview"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "start", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stop", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "capture", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "captureSample", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "flip", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getSupportedFlashModes", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setFlashMode", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "startRecordVideo", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stopRecordVideo", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "isCameraStarted", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "addShape", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "startFromImage", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "rotateReview", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setZoom", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "cancelReview", returnType: CAPPluginReturnPromise)
    ]

    var previewView: UIView!
    var shapesOverlay: ShapesOverlayView!
    var cameraPosition = String()
    let cameraController = CameraController()
    
    var x: CGFloat?
    var y: CGFloat?
    
    var width: CGFloat?
    var height: CGFloat?
    var paddingBottom: CGFloat?
    var rotateWhenOrientationChanged: Bool?
    var toBack: Bool?
    var storeToFile: Bool?
    var enableZoom: Bool?
    var highResolutionOutput: Bool = false
    var disableAudio: Bool = false
    
    var isInReviewMode: Bool = false
    var reviewScrollView: UIScrollView?
    var reviewContainerView: UIView?
    var reviewImageView: UIImageView?
    var capturedImageForReview: UIImage?
    var reviewQuality: Int = 85

    @objc func rotated() {
        guard let previewView = self.previewView,
              let x = self.x,
              let y = self.y,
              let width = self.width,
              let height = self.height else {
            return
        }

        let adjustedHeight = self.paddingBottom != nil ? height - self.paddingBottom! : height

        if UIApplication.shared.statusBarOrientation.isLandscape {
            previewView.frame = CGRect(x: y, y: x, width: max(adjustedHeight, width), height: min(adjustedHeight, width))
            self.cameraController.previewLayer?.frame = previewView.frame
        }

        if UIApplication.shared.statusBarOrientation.isPortrait {
            previewView.frame = CGRect(x: x, y: y, width: min(adjustedHeight, width), height: max(adjustedHeight, width))
            self.cameraController.previewLayer?.frame = previewView.frame
        }

        cameraController.updateVideoOrientation()
    }

    @objc func start(_ call: CAPPluginCall) {
        self.cameraPosition = call.getString("position") ?? "rear"
        self.highResolutionOutput = call.getBool("enableHighResolution") ?? false
        self.cameraController.highResolutionOutput = self.highResolutionOutput

        if call.getInt("width") != nil {
            self.width = CGFloat(call.getInt("width")!)
        } else {
            self.width = UIScreen.main.bounds.size.width
        }
        if call.getInt("height") != nil {
            self.height = CGFloat(call.getInt("height")!)
        } else {
            self.height = UIScreen.main.bounds.size.height
        }
        self.x = call.getInt("x") != nil ? CGFloat(call.getInt("x")!)/UIScreen.main.scale: 0
        self.y = call.getInt("y") != nil ? CGFloat(call.getInt("y")!)/UIScreen.main.scale: 0
        if call.getInt("paddingBottom") != nil {
            self.paddingBottom = CGFloat(call.getInt("paddingBottom")!)
        }

        self.rotateWhenOrientationChanged = call.getBool("rotateWhenOrientationChanged") ?? true
        self.toBack = call.getBool("toBack") ?? false
        self.storeToFile = call.getBool("storeToFile") ?? false
        self.enableZoom = call.getBool("enableZoom") ?? false
        self.disableAudio = call.getBool("disableAudio") ?? false

        AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
            guard granted else {
                call.reject("permission failed")
                return
            }

            DispatchQueue.main.async {
                if self.cameraController.captureSession?.isRunning ?? false {
                    call.reject("camera already started")
                } else {
                    self.cameraController.prepare(cameraPosition: self.cameraPosition, disableAudio: self.disableAudio) {error in
                        if let error = error {
                            print(error)
                            call.reject(error.localizedDescription)
                            return
                        }
                        guard let height = self.height, let width = self.width else {
                            call.reject("Invalid dimensions")
                            return
                        }

                        let adjustedHeight = self.paddingBottom != nil ? height - self.paddingBottom! : height
                        self.previewView = UIView(frame: CGRect(x: self.x ?? 0, y: self.y ?? 0, width: width, height: adjustedHeight))
                        
                        self.webView?.isOpaque = false
                        self.webView?.backgroundColor = UIColor.clear
                        self.webView?.scrollView.backgroundColor = UIColor.clear
                        self.webView?.superview?.addSubview(self.previewView)
                        
                        if let toBack = self.toBack, toBack {
                            self.webView?.superview?.bringSubviewToFront(self.webView!)
                        }
                        
                        try? self.cameraController.displayPreview(on: self.previewView)
                        
                        self.shapesOverlay = ShapesOverlayView(frame: CGRect(x: self.x ?? 0, y: self.y ?? 0, width: width, height: adjustedHeight))
                        self.shapesOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                        self.webView?.superview?.addSubview(self.shapesOverlay)

                        let frontView = (self.toBack ?? false) ? self.webView : self.previewView
                        self.cameraController.setupGestures(target: frontView ?? self.previewView, enableZoom: self.enableZoom ?? false)

                        if self.enableZoom == true {
                           self.setupZoomControl()
                        }

                        if self.rotateWhenOrientationChanged == true {
                            NotificationCenter.default.addObserver(self, selector: #selector(CameraPreview.rotated), name: UIDevice.orientationDidChangeNotification, object: nil)
                        }

                        call.resolve()

                    }
                }
            }
        })

    }

    @objc func flip(_ call: CAPPluginCall) {
        do {
            try self.cameraController.switchCameras()
            call.resolve()
        } catch {
            call.reject("failed to flip camera")
        }
    }

    @objc func stop(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            if self.cameraController.captureSession?.isRunning ?? false {
                self.cameraController.captureSession?.stopRunning()

                if self.rotateWhenOrientationChanged == true {
                    NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
                }

                if let previewView = self.previewView {
                    previewView.removeFromSuperview()
                    self.previewView = nil
                }
                if let shapesOverlay = self.shapesOverlay {
                    shapesOverlay.removeFromSuperview()
                    self.shapesOverlay = nil
                }
                self.webView?.isOpaque = true
                call.resolve()
            } else {
                call.reject("camera already stopped")
            }
        }
    }
    
    @objc func getTempFilePath() -> URL {
        let path = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let identifier = UUID()
        let randomIdentifier = identifier.uuidString.replacingOccurrences(of: "-", with: "")
        let finalIdentifier = String(randomIdentifier.prefix(8))
        let fileName="cpcp_capture_"+finalIdentifier+".jpg"
        let fileUrl=path.appendingPathComponent(fileName)
        return fileUrl
    }

    @objc func capture(_ call: CAPPluginCall) {
        DispatchQueue.main.async {

            let quality: Int? = call.getInt("quality", 85)

            self.cameraController.captureImage { (image, error) in

                guard var image = image else {
                    print(error ?? "Image capture error")
                    guard let error = error else {
                        call.reject("Image capture error")
                        return
                    }
                    call.reject(error.localizedDescription)
                    return
                }
                
                if let overlay = self.shapesOverlay {
                    image = self.mergeOverlay(image: image, overlay: overlay)
                }
                
                let imageData: Data?
                if self.cameraController.currentCameraPosition == .front {
                    let flippedImage = image.withHorizontallyFlippedOrientation()
                    imageData = flippedImage.jpegData(compressionQuality: CGFloat(quality!/100))
                } else {
                    imageData = image.jpegData(compressionQuality: CGFloat(quality!/100))
                }

                if self.storeToFile == false {
                    let imageBase64 = imageData?.base64EncodedString()
                    call.resolve(["value": imageBase64!])
                } else {
                    do {
                        let fileUrl=self.getTempFilePath()
                        try imageData?.write(to: fileUrl)
                        call.resolve(["value": fileUrl.absoluteString])
                    } catch {
                        call.reject("error writing image to file")
                    }
                }
            }
        }
    }
    
    
    func mergeOverlay(image: UIImage, overlay: UIView) -> UIImage {
        let size = image.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        
        return renderer.image { context in
            image.draw(at: .zero)
            
            let scaleX = size.width / overlay.bounds.width
            let scaleY = size.height / overlay.bounds.height
            
            context.cgContext.scaleBy(x: scaleX, y: scaleY)
            
            overlay.layer.render(in: context.cgContext)
        }
    }

    @objc func captureSample(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            let quality: Int? = call.getInt("quality", 85)

            self.cameraController.captureSample { image, error in
                guard let image = image else {
                    print("Image capture error: \(String(describing: error))")
                    call.reject("Image capture error: \(String(describing: error))")
                    return
                }

                let imageData: Data?
                if self.cameraPosition == "front" {
                    let flippedImage = image.withHorizontallyFlippedOrientation()
                    imageData = flippedImage.jpegData(compressionQuality: CGFloat(quality!/100))
                } else {
                    imageData = image.jpegData(compressionQuality: CGFloat(quality!/100))
                }

                if self.storeToFile == false {
                    let imageBase64 = imageData?.base64EncodedString()
                    call.resolve(["value": imageBase64!])
                } else {
                    do {
                        let fileUrl = self.getTempFilePath()
                        try imageData?.write(to: fileUrl)
                        call.resolve(["value": fileUrl.absoluteString])
                    } catch {
                        call.reject("Error writing image to file")
                    }
                }
            }
        }
    }

    @objc func getSupportedFlashModes(_ call: CAPPluginCall) {
        do {
            let supportedFlashModes = try self.cameraController.getSupportedFlashModes()
            call.resolve(["result": supportedFlashModes])
        } catch {
            call.reject("failed to get supported flash modes")
        }
    }

    @objc func setFlashMode(_ call: CAPPluginCall) {
        guard let flashMode = call.getString("flashMode") else {
            call.reject("failed to set flash mode. required parameter flashMode is missing")
            return
        }
        do {
            var flashModeAsEnum: AVCaptureDevice.FlashMode?
            switch flashMode {
            case "off":
                flashModeAsEnum = AVCaptureDevice.FlashMode.off
            case "on":
                flashModeAsEnum = AVCaptureDevice.FlashMode.on
            case "auto":
                flashModeAsEnum = AVCaptureDevice.FlashMode.auto
            default: break
            }
            if flashModeAsEnum != nil {
                try self.cameraController.setFlashMode(flashMode: flashModeAsEnum!)
            } else if flashMode == "torch" {
                try self.cameraController.setTorchMode()
            } else {
                call.reject("Flash Mode not supported")
                return
            }
            call.resolve()
        } catch {
            call.reject("failed to set flash mode")
        }
    }

    @objc func startRecordVideo(_ call: CAPPluginCall) {
        DispatchQueue.main.async {

            let quality: Int? = call.getInt("quality", 85)

            self.cameraController.captureVideo { (image, error) in

                guard let image = image else {
                    print(error ?? "Image capture error")
                    guard let error = error else {
                        call.reject("Image capture error")
                        return
                    }
                    call.reject(error.localizedDescription)
                    return
                }
                call.resolve(["value": image.absoluteString])
            }
        }
    }

    @objc func stopRecordVideo(_ call: CAPPluginCall) {

        self.cameraController.stopRecording { (_) in

        }
    }

    @objc func isCameraStarted(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            if self.cameraController.captureSession?.isRunning ?? false {
                call.resolve(["value": true])
            } else {
                call.resolve(["value": false])
            }
        }
    }

    @objc func addShape(_ call: CAPPluginCall) {
        let type = call.getString("type") ?? "square"
        let colorString = call.getString("color") ?? "#FF0000"
        let color = self.color(from: colorString)
        
        DispatchQueue.main.async {
            if self.shapesOverlay != nil {
                self.shapesOverlay.addShape(type: type, color: color)
                call.resolve()
            } else {
                call.reject("Camera not running")
            }
        }
    }
    
    func color(from hex: String) -> UIColor {
        var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if (cString.hasPrefix("#")) {
            cString.remove(at: cString.startIndex)
        }

        if ((cString.count) != 6) {
            return UIColor.gray
        }

        var rgbValue:UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)

        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
    
    
    @objc func captureForReview(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.reviewQuality = call.getInt("quality") ?? 85
            
            self.cameraController.captureImage { (image, error) in
                guard let image = image else {
                    print(error ?? "Image capture error")
                    call.reject(error?.localizedDescription ?? "Image capture error")
                    return
                }
                
                DispatchQueue.main.async {
                    self.capturedImageForReview = image
                    
                    self.cameraController.captureSession?.stopRunning()
                    
                    self.cameraController.previewLayer?.isHidden = true
                    
                    let scrollView = UIScrollView(frame: self.previewView.bounds)
                    scrollView.delegate = self
                    scrollView.minimumZoomScale = 1.0
                    scrollView.maximumZoomScale = 3.0
                    scrollView.showsHorizontalScrollIndicator = false
                    scrollView.showsVerticalScrollIndicator = false
                    self.reviewScrollView = scrollView
                    
                    let containerView = UIView(frame: scrollView.bounds)
                    self.reviewContainerView = containerView
                    scrollView.addSubview(containerView)
                    
                    let imageView = UIImageView(frame: containerView.bounds)
                    imageView.image = image
                    imageView.contentMode = .scaleAspectFit 
                    imageView.clipsToBounds = true
                    self.reviewImageView = imageView
                    containerView.addSubview(imageView)
                    
                    self.previewView.insertSubview(scrollView, at: 0)
                    
                    if let overlay = self.shapesOverlay {
                        overlay.removeFromSuperview()
                        overlay.frame = containerView.bounds
                        containerView.addSubview(overlay)
                        
                        overlay.removeAllShapes()
                    }
                    
                    self.isInReviewMode = true
                    call.resolve()
                }
            }
        }
    }
    
    @objc func confirmReview(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard self.isInReviewMode, var image = self.capturedImageForReview else {
                call.reject("Not in review mode")
                return
            }
            
            let editData = self.shapesOverlay?.getOverlayData()
            
            var originalResult: String = ""
            if self.cameraController.currentCameraPosition == .front {
                image = image.withHorizontallyFlippedOrientation()
            }
            
            let originalData = image.jpegData(compressionQuality: CGFloat(self.reviewQuality) / 100.0)
            if self.storeToFile == false {
                originalResult = originalData?.base64EncodedString() ?? ""
            } else {
                originalResult = originalData?.base64EncodedString() ?? ""
            }
            
            var finalImage = image
            if let overlay = self.shapesOverlay {
                finalImage = self.mergeOverlay(image: finalImage, overlay: overlay)
            }
            
            let finalData = finalImage.jpegData(compressionQuality: CGFloat(self.reviewQuality) / 100.0)
            let finalResult = finalData?.base64EncodedString() ?? ""
            
            call.resolve([
                "value": finalResult,
                "originalValue": originalResult,
                "editData": editData ?? ""
            ])
            
            self.exitReviewMode()
        }

    }
    
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.reviewContainerView
    }
    
    func rotateImage(_ image: UIImage) -> UIImage? {
        let radians = CGFloat.pi / 2

        var rotatedRect = CGRect(origin: .zero, size: image.size)
            .applying(CGAffineTransform(rotationAngle: radians))
        rotatedRect.origin = .zero

        UIGraphicsBeginImageContextWithOptions(rotatedRect.size, false, image.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        context.translateBy(x: rotatedRect.size.width / 2,
                            y: rotatedRect.size.height / 2)

        context.rotate(by: radians)

        image.draw(
            in: CGRect(
                x: -image.size.width / 2,
                y: -image.size.height / 2,
                width: image.size.width,
                height: image.size.height
            )
        )

        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return rotatedImage
    }
    
    @objc func rotateReview(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard self.isInReviewMode, let image = self.capturedImageForReview else {
                call.reject("Not in review mode or no image")
                return
            }
            
            if let rotatedImage = self.rotateImage(image) {
                self.capturedImageForReview = rotatedImage
                self.reviewImageView?.image = rotatedImage
                
                self.shapesOverlay?.rotateShapes(
                    currentImageSize: image.size,
                    viewSize: self.reviewContainerView!.bounds.size
                )
                
                call.resolve()
            } else {
                call.reject("Failed to rotate")
            }
        }
    }
    
    @objc func startFromImage(_ call: CAPPluginCall) {
         DispatchQueue.main.async {
             guard let base64 = call.getString("base64"),
                   let data = Data(base64Encoded: base64),
                   let image = UIImage(data: data) else {
                 call.reject("Invalid image data")
                 return
             }
             
             let editData = call.getString("editData")
             
             if self.reviewScrollView == nil {
                 let scrollView = UIScrollView(frame: self.previewView.bounds)
                 scrollView.delegate = self
                 scrollView.minimumZoomScale = 1.0
                 scrollView.maximumZoomScale = 3.0
                 scrollView.showsHorizontalScrollIndicator = false
                 scrollView.showsVerticalScrollIndicator = false
                 self.reviewScrollView = scrollView
                 
                 let containerView = UIView(frame: scrollView.bounds)
                 self.reviewContainerView = containerView
                 scrollView.addSubview(containerView)
                 
                 let imageView = UIImageView(frame: containerView.bounds)
                 imageView.contentMode = .scaleAspectFit
                 self.reviewImageView = imageView
                 containerView.addSubview(imageView)
                 
                 self.previewView.insertSubview(scrollView, at: 0)
             }
             
             self.reviewImageView?.image = image
             self.capturedImageForReview = image 
             
             self.cameraController.captureSession?.stopRunning()
             self.cameraController.previewLayer?.isHidden = true
             
             self.isInReviewMode = true
             
             if let overlay = self.shapesOverlay {
                 overlay.removeFromSuperview()
                 overlay.frame = self.reviewContainerView!.bounds
                 self.reviewContainerView!.addSubview(overlay)
                 
                 if let editJson = editData {
                     overlay.loadOverlayData(editJson)
                 } else {
                     overlay.removeAllShapes()
                 }
             }
             

             call.resolve()
         }
    }
    
    @objc func setZoom(_ call: CAPPluginCall) {
        let zoomFactor = CGFloat(call.getFloat("zoom") ?? 1.0)
        do {
            try cameraController.setZoom(zoomFactor)
            call.resolve()
        } catch {
            call.reject("Failed to set zoom")
        }
    }
    
    @objc func cancelReview(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard self.isInReviewMode else {
                call.reject("Not in review mode")
                return
            }
            
            self.exitReviewMode()
            
            self.cameraController.captureSession?.startRunning()
            self.cameraController.previewLayer?.isHidden = false
            
            call.resolve()
        }
    }
    
    private func exitReviewMode() {
        self.reviewScrollView?.removeFromSuperview()
        self.reviewScrollView = nil
        self.reviewContainerView = nil
        self.reviewImageView = nil
        
        if let overlay = self.shapesOverlay {
            overlay.removeFromSuperview()
            if let superview = self.webView?.superview {
                superview.addSubview(overlay)
            } else {
                self.previewView.addSubview(overlay)
            }
            overlay.frame = self.previewView.bounds 
        }
        
        self.capturedImageForReview = nil
        
        self.shapesOverlay?.removeAllShapes()
        
        self.isInReviewMode = false
    }

    var zoomStackView: UIStackView?
    
    func setupZoomControl() {
        DispatchQueue.main.async {
            guard let parentView = self.previewView else { return }
            
            self.zoomStackView?.removeFromSuperview()
            
            let stackView = UIStackView()
            stackView.axis = .horizontal
            stackView.distribution = .fillEqually
            stackView.spacing = 10
            stackView.alignment = .center
            stackView.translatesAutoresizingMaskIntoConstraints = false
            
            let values: [(String, CGFloat)] = [("0.5x", 0.5), ("1x", 1.0), ("2x", 2.0), ("∞", 999.0)]
            
            for (title, value) in values {
                let button = UIButton(type: .system)
                button.setTitle(title, for: .normal)
                button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
                button.setTitleColor(.white, for: .normal)
                button.layer.cornerRadius = 15
                button.heightAnchor.constraint(equalToConstant: 30).isActive = true
                button.tag = Int(value * 10) 
                
                button.addAction(UIAction(handler: { [weak self] _ in
                    self?.zoomTo(value)
                }), for: .touchUpInside)
                
                stackView.addArrangedSubview(button)
            }
            
            parentView.addSubview(stackView)
            self.zoomStackView = stackView
            
            NSLayoutConstraint.activate([
                stackView.centerXAnchor.constraint(equalTo: parentView.centerXAnchor),
                stackView.bottomAnchor.constraint(equalTo: parentView.bottomAnchor, constant: -20),
                stackView.widthAnchor.constraint(equalToConstant: 250),
                stackView.heightAnchor.constraint(equalToConstant: 40)
            ])
            
            parentView.bringSubviewToFront(stackView)
        }
    }
    
    func zoomTo(_ factor: CGFloat) {
         DispatchQueue.global(qos: .userInitiated).async {
             do {
                 var targetZoom = factor
                 if factor == 999.0 {
                     if let device = self.cameraController.currentCameraPosition == .front ? self.cameraController.frontCamera : self.cameraController.rearCamera {
                         targetZoom = device.activeFormat.videoMaxZoomFactor
                     }
                 }
                 try self.cameraController.setZoom(targetZoom)
             } catch {
                 print("Failed to set zoom: \(error)")
             }
         }
    }

}
