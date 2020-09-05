//
//  PaintViewController.swift
//  CoPaint
//
//  Created by 张睿杰 on 2020/9/5.
//  Copyright © 2020 张睿杰. All rights reserved.
//

import UIKit

class ColorButton: UIButton {
    
    var color: UIColor!
    
    override func draw(_ rect: CGRect) {
        let path = UIBezierPath(ovalIn: rect)
        color.setFill()
        path.fill()
    }
}

class PaintViewController: UIViewController {

    @IBOutlet weak var scrollview: UIScrollView!
    @IBOutlet weak var ColorSelectionView: UIView!
    @IBOutlet weak var backgroundview: DrawingView!
    @IBOutlet weak var backgroundHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var backgroundWidthConstraint: NSLayoutConstraint!
    var room: Int?
    var templateImage: UIImage!
    var templateIndex: Int?
    
    let firstButton = ColorButton(frame: CGRect(x: 15, y: 10, width: 25, height: 25))
    let secondButton = ColorButton(frame: CGRect(x: 55, y: 10, width: 25, height: 25))
    let thirdButton = ColorButton(frame: CGRect(x: 95, y: 10, width: 25, height: 25))
    let fourthButton = ColorButton(frame: CGRect(x: 135, y: 10, width: 25, height: 25))
    let checkIcon = UIImageView(image: UIImage(named: "checkIcon"))
    var selectedColor: UIColor = .blue
    
    @objc func buttonTapped(_ sender: ColorButton) {
        print("button tapped")
        checkIcon.frame = sender.frame.insetBy(dx: 5, dy: 5)
        checkIcon.setNeedsLayout()
        selectedColor = sender.color
        backgroundview.selectedColor = selectedColor
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        scrollview.panGestureRecognizer.allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber]
        scrollview.panGestureRecognizer.minimumNumberOfTouches = 1
        scrollview.backgroundColor = #colorLiteral(red: 0.921431005, green: 0.9214526415, blue: 0.9214410186, alpha: 1)
        
        let buttons = [(firstButton, UIColor.red), (secondButton, UIColor.yellow), (thirdButton, UIColor.blue), (fourthButton, UIColor.green)]
        for (button, color) in buttons {
            button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
            button.color = color
            ColorSelectionView.addSubview(button)
        }
        ColorSelectionView.addSubview(checkIcon)
        
        if let room = self.room {
            CoPaintWebSocket.shared.join(roomId: room, completion: {
                let index = CoPaintWebSocket.shared.paintingId
                let name = templates[index]
                let imageURL = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "templates")!
                if let image = UIImage(contentsOfFile: imageURL.path)?.cgImage {
                    self.backgroundview.image = image
                    self.backgroundWidthConstraint.constant = CGFloat(image.width)
                    self.backgroundHeightConstraint.constant = CGFloat(image.height)
                    self.backgroundview.setNeedsDisplay()
                }
            }, onTouch: { touch in
                print(touch, "received")
                if let image = self.backgroundview.image {
                    self.backgroundview.image = self.backgroundview.manipulatePixel(imageRef: image, point: (touch.x, touch.y), color: UIColor(red: CGFloat(touch.r), green: CGFloat(touch.g), blue: CGFloat(touch.b), alpha: 255))
                    self.backgroundview.setNeedsDisplay()
                }
            })
        } else {
            if let image = templateImage.cgImage {
                self.backgroundview.image = image
                self.backgroundWidthConstraint.constant = CGFloat(image.width)
                self.backgroundHeightConstraint.constant = CGFloat(image.height)
            }
            CoPaintWebSocket.shared.create(paintingId: templateIndex!, completion: {
                print(CoPaintWebSocket.shared.roomId)
                print(CoPaintWebSocket.shared.paintingId)
            }, onTouch: { touch in
                print(touch, "received")
                if let image = self.backgroundview.image {
                    self.backgroundview.image = self.backgroundview.manipulatePixel(imageRef: image, point: (touch.x, touch.y), color: UIColor(red: CGFloat(touch.r), green: CGFloat(touch.g), blue: CGFloat(touch.b), alpha: 255))
                    self.backgroundview.setNeedsDisplay()
                }
            })
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        var size = view.bounds.size
//        size.height -= topview.bounds.height
//        size.height -= 20
        
        updateMinZoomScaleForSize(size)
    }
    
    func updateMinZoomScaleForSize(_ size: CGSize) {
        let widthScale = size.width / backgroundview.bounds.width
        let heightScale = size.height / backgroundview.bounds.height
        let minScale = min(widthScale, heightScale)
        scrollview.minimumZoomScale = minScale
        if minScale < 6 {
            scrollview.maximumZoomScale = CGFloat(6.0)
        } else {
            scrollview.maximumZoomScale = minScale
        }
        scrollview.zoomScale = minScale
        scrollViewDidZoom(scrollview)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "sharesegue" {
            let controller = segue.destination as! SharePopoverViewController
            controller.roomId = CoPaintWebSocket.shared.roomId
        }
    }
    
    
}

extension PaintViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return backgroundview
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if scrollView.zoomScale > 2 {
            backgroundview.layer.contentsScale = scrollView.zoomScale
        } else {
            backgroundview.layer.contentsScale = 2
        }
        backgroundview.setNeedsDisplay()
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        var size = view.bounds.size
        // ALERT: THIS DOES WORK, BUT DID NOT KNOW WHY, TRY TO FIND A FUNCTION TO CALCULATE THE ADJUSTION OF SIZE
//        size.height -= topview.bounds.height
//        size.height -= 20
        let offsetX = max((size.width - scrollView.contentSize.width) * 0.5, 0)
        let offsetY = max((size.height - scrollView.contentSize.height - 80) * 0.45, 0)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: 0, right: 0)
    }
}
