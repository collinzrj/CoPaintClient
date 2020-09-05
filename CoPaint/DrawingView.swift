//
//  DrawingView.swift
//  CoPaint
//
//  Created by 张睿杰 on 2020/9/5.
//  Copyright © 2020 张睿杰. All rights reserved.
//

import UIKit
import CoreGraphics

class DrawingView: UIView {
    
    var image: CGImage!
    var paths = [UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 500, height: 500)),
                 UIBezierPath(ovalIn: CGRect(x: 100, y: 100, width: 50, height: 50)),
                 UIBezierPath(ovalIn: CGRect(x: 300, y: 200, width: 50, height: 50))]
    var filled: [Int] = []
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let point = touches.first?.location(in: self) {
//            for (index, path) in paths.enumerated() {
//                print(point)
//                print(path.contains(point))
//                if path.contains(point) {
//                    filled.append(index)
//                }
//            }
//            setNeedsDisplay()
            self.image = manipulatePixel(imageRef: image, point: point, color: .black)
            setNeedsDisplay()
        }
    }
    
    func manipulatePixel(imageRef: CGImage, point: CGPoint, color: UIColor) -> CGImage? {
        let pixelWidth = imageRef.width
        let pixelHeight = imageRef.height
        print(point, pixelHeight, pixelWidth, self.frame)
        let bitmapBytesPerRow = pixelWidth * 4
        let bitmapByteCount = bitmapBytesPerRow * pixelHeight
        
        let colorSpace:CGColorSpace = CGColorSpaceCreateDeviceRGB()
        
        let bitmapData:UnsafeMutableRawPointer = malloc(Int(bitmapByteCount))
        
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue
        let context = CGContext(data: nil, width: pixelWidth, height: pixelHeight, bitsPerComponent: 8, bytesPerRow: bitmapBytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
        
        let width = imageRef.width
        let height = imageRef.height
        let rect = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        
        context?.draw(imageRef, in: rect)
        
        let data = context?.data
        //let originData = data!.load(as: UnsafeMutablePointer<UInt8>.self)
        let dataType = data!.bindMemory(to: UInt8.self, capacity: width * height)
//        let dataType = UnsafeMutableBufferPointer<UInt8>(start: data, count: width * height * 4)
        
        var alpha, red, green, blue: UInt8
        var base, offset:Int
        let frame_width = self.frame.width
        let frame_height = self.frame.height
        // may still exist some problem
        let pixel_x = Int(point.x * self.bounds.width / CGFloat(pixelWidth))
        let pixel_y = Int(CGFloat(pixelHeight) - point.y * self.bounds.height / CGFloat(pixelHeight))
    
        var pointsQueue = [(Int, Int)]()
        let t1 = CFAbsoluteTimeGetCurrent()
        pointsQueue.append((pixel_x, pixel_y))
        while pointsQueue.count > 0 {
            let currentPoint = pointsQueue.popLast()!
            let offset = currentPoint.1 * height * 4 + currentPoint.0 * 4
            dataType[offset] = UInt8(255)
            dataType[offset + 1] = UInt8(255)
            dataType[offset + 2] = UInt8(0)
            dataType[offset + 3] = UInt8(0)
            
            for i in [-1, 0, 1] {
                for j in [-1, 0, 1] {
                    let newPoint = (currentPoint.0 + i, currentPoint.1 + j)
                    let new_offset = newPoint.1 * height * 4 + newPoint.0 * 4
                    if newPoint.0 > 0 && newPoint.0 < width && newPoint.1 > 0 && newPoint.1 < height && dataType[new_offset + 1] > 250 && dataType[new_offset + 1] > 250 && dataType[new_offset + 2] > 250 {
                        pointsQueue.append(newPoint)
                    }
                }
            }
        }
        let t2 = CFAbsoluteTimeGetCurrent()
        print(t2 - t1)
        
        
//        for y in pixel_y - 50...pixel_y + 50 {
//            if y > height || y < 0 {
//                continue
//            }
//            base = y * height * 4
//            for x in pixel_x - 50...pixel_x + 50 {
//                if x > width || x < 0 {
//                    continue
//                }
//                offset = base + x * 4
//                dataType[offset] = UInt8(255)
//                dataType[offset + 1] = UInt8(255)
//            }
//        }
            

        var s = ""
        for y in 0...(height - 1) {

            base = y * height * 4
            for x in 0...(width - 1) {
                offset = base + x * 4
                s += "\(dataType[offset]) \(dataType[offset + 1]) \(dataType[offset + 2]) \(dataType[offset + 3]) \n"
            }
        }
        let encoder = JSONEncoder()
        let d = try! encoder.encode(s)
        let path = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        try! d.write(to: path.appendingPathComponent(UUID().uuidString))
        
        let imageRef = context?.makeImage()

//        free(data)
        return imageRef
    }

    override func draw(_ rect: CGRect) {
//        for (index, path) in paths.enumerated() {
//            UIColor.blue.setStroke()
//            path.stroke()
//            print(index, filled)
//            if filled.contains(index) {
//                UIColor.blue.setFill()
//                path.fill()
//            }
//        }
        let context = UIGraphicsGetCurrentContext()
        context?.clear(bounds)
        context?.draw(image, in: bounds)
        let uiimage = UIImage(cgImage: image)
        let data = uiimage.pngData()
        let path = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        try! data?.write(to: path.appendingPathComponent(UUID().uuidString).appendingPathExtension("png"))
        print(path)
    }

}