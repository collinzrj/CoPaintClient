//
//  PaintViewController.swift
//  CoPaint
//
//  Created by 张睿杰 on 2020/9/5.
//  Copyright © 2020 张睿杰. All rights reserved.
//

import UIKit

class PaintViewController: UIViewController {

    @IBOutlet weak var scrollview: UIScrollView!
    @IBOutlet weak var backgroundview: DrawingView!
    var room: Int?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        scrollview.panGestureRecognizer.allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber]
        scrollview.panGestureRecognizer.minimumNumberOfTouches = 1
        scrollview.backgroundColor = .green
        
        backgroundview.image = UIImage(named: "snowman3")?.cgImage
        
        if let room = self.room {
            CoPaintWebSocket.shared.join(id: room, completion: {}, onTouch: { touch in
                print(touch, "received")
                self.backgroundview.image = self.backgroundview.manipulatePixel(imageRef: self.backgroundview.image, point: (touch.x, touch.y), color: .black)
                self.backgroundview.setNeedsDisplay()
            })
        } else {
            CoPaintWebSocket.shared.create(completion: {
                print(CoPaintWebSocket.shared.roomId)
            }, onTouch: { touch in
                print(touch, "received")
                self.backgroundview.image = self.backgroundview.manipulatePixel(imageRef: self.backgroundview.image, point: (touch.x, touch.y), color: .black)
                self.backgroundview.setNeedsDisplay()
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
        let offsetY = max((size.height - scrollView.contentSize.height) * 0.5, 0)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: 0, right: 0)
    }
}
