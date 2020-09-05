//
//  PaintViewController.swift
//  CoPaint
//
//  Created by 张睿杰 on 2020/9/5.
//  Copyright © 2020 张睿杰. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

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
    
    @IBAction func uploadTapped(_ sender: Any) {
        dump(backgroundview.image)
        if let image = backgroundview.image {
            let pngData = UIImage(cgImage: image).pngData()
            let string = pngData?.base64EncodedString()
            AF.request("https://go.hqy.moe/paintings/upload", method: .post, parameters: [
                "paintingId": CoPaintWebSocket.shared.paintingId,
                "image": string ?? ""
            ]).response { (data) in
                AF.request("https://go.hqy.moe/paintings/list", method: .get, parameters: [
                    "paintingId": CoPaintWebSocket.shared.paintingId
                ]).response { (data) in
                        let json = try! JSON(data: data.data!)
                       let photos = json["data"].array!
                       let images: [UIImage] = photos.map { (photo) -> UIImage in
                           var base64 = photo["image"].string ?? ""
                           base64 = base64.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
                           // print(base64)
                           if let decodedData = Data(base64Encoded: base64) {
                               let image = UIImage(data: decodedData)
                               return image!
                           } else {
                               print("error when decoding, return empty image")
                               return UIImage()
                           }
                       }
                       print(images, "images get")
                       self.performSegue(withIdentifier: "similarsegue", sender: images)
                       print("perform segue")
                }
            }
        }
    }
    
    @IBAction func saveTapped(_ sender: Any) {
        if let image = backgroundview.image {
            let data = UIImage(cgImage: image).pngData()
            if let index = templateIndex {
                let name = templates[index]
                let date = Date()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy/MM/dd/hh/mm/ss"
                let datestring = dateFormatter.string(from: date)
                do {
                    try data?.write(to: documentsPath.appendingPathComponent("\(UUID().uuidString).png"))
                    let alert = UIAlertController(title: "Picture Saved", message: nil, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "ok", style: .cancel, handler: nil))
                    self.present(alert, animated: true)
                } catch {
                    let alert = UIAlertController(title: "Save Picture fail", message: nil, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "ok", style: .cancel, handler: nil))
                    self.present(alert, animated: true)
                }
                print("file saved")
            }
        }
        print("finish")
    }
    
    @IBAction func shareTapped(_ sender: Any) {
        let alert = UIAlertController(title: "Room Code is\n" + String(CoPaintWebSocket.shared.roomId), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ok", style: .cancel, handler: nil))
        self.present(alert, animated: true)
    }
    
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
            print("send room id \(room)")
            CoPaintWebSocket.shared.join(roomId: room, completion: {
                let index = CoPaintWebSocket.shared.paintingId
                if CoPaintWebSocket.shared.roomId == 0 {
                    let alert = UIAlertController(title: "Wrong Code", message: nil, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "ok", style: .default, handler: nil))
                    self.present(alert, animated: true)
                    return
                }
                self.templateIndex = index
                let name = templates[index]
                let imageURL = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "templates")!
                if let image = UIImage(contentsOfFile: imageURL.path)?.cgImage {
                    self.backgroundview.image = image
                    self.backgroundWidthConstraint.constant = CGFloat(image.width)
                    self.backgroundHeightConstraint.constant = CGFloat(image.height)
                    self.backgroundview.setNeedsDisplay()
                    let touches = CoPaintWebSocket.shared.touches
                    for touch in touches {
                        print(touch)
                        self.backgroundview.image = self.backgroundview.manipulatePixel(imageRef: self.backgroundview.image!, point: (touch.x, touch.y), color: UIColor(red: CGFloat(touch.r), green: CGFloat(touch.g), blue: CGFloat(touch.b), alpha: 255))
                    }
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
        print("enter prepare")
        if segue.identifier == "sharesegue" {
            print("another here")
            let controller = segue.destination as! SharePopoverViewController
            controller.roomId = CoPaintWebSocket.shared.roomId
        } else if segue.identifier == "similarsegue" {
            print("begin prepare")
            let controller = segue.destination as! SimilarViewController
            let images = sender as! [UIImage]
            print("segue images", images)
            controller.images = images
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
