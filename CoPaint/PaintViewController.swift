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

    func manipulatePixel(imageRef: CGImage, point: CGPoint, color: UIColor) -> CGImage? {
            let pixelWidth = imageRef.width
            let pixelHeight = imageRef.height
            let bitmapBytesPerRow = pixelWidth * 4
            let bitmapByteCount = bitmapBytesPerRow * pixelHeight
            
            let colorSpace:CGColorSpace = CGColorSpaceCreateDeviceRGB()
            
            let bitmapData:UnsafeMutableRawPointer = malloc(Int(bitmapByteCount))
            
            
            let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue
            let context = CGContext(data: nil, width: pixelWidth, height: pixelHeight, bitsPerComponent: 8, bytesPerRow: bitmapBytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
            
            let width = imageRef.width
            let height = imageRef.height
            let rect = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
            
    //        context?.draw(imageRef, in: rect)
            
            let data = context?.data
            let dataType = data!.bindMemory(to: UInt8.self, capacity: width * height * 4)
    //        let dataType = UnsafeMutableBufferPointer<UInt8>(start: data, count: width * height * 4)
            
            var alpha, red, green, blue: UInt8
            var base, offset:Int
            let pixel_x = Int(point.x)
            let pixel_y = Int(point.y)
        
            for y in pixel_y - 50...pixel_y + 50 {
                    
                base = y * height * 4
                for x in pixel_x - 50...pixel_x + 50 {
                    offset = base + x * 4
                    dataType[offset] = UInt8(255)
                    dataType[offset + 1] = UInt8(255)
                }
            }

            let imageRef = context?.makeImage()

    //        free(data)
            return imageRef
        }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print(touches.first?.location(in: backgroundview))
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
