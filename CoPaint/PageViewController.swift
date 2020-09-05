//
//  CanvasViewController.swift
//  realtimedrawing
//
//  Created by 张睿杰 on 2019/11/3.
//  Copyright © 2019 张睿杰. All rights reserved.
//

import UIKit

protocol PageViewControllerDelegate: class {
    func BrushSelectionNeedsUpdate()
    func ConnectionStatusNeedsUpdate(text: String)
}

class PageViewController: UIViewController {
    
    @IBOutlet weak var scrollview: UIScrollView!
    // server as background of the drawboardview
    @IBOutlet weak var rulerview: UIView!
    @IBOutlet weak var topview: UIView!
    @IBOutlet weak var backgroundview: DrawPDFView!
    @IBOutlet weak var backgroundTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var backgroundBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var backgroundTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var backgroundLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var backgroundWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var backgroundHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var ColorButton: UIButton!
    
    var drawboardview = DrawBoardView()
    var drawactiveview = DrawActiveView()
    var tempPdfview = DrawPDFView()
    
    var brush: Brush!
    var connected: Bool!
    var topview_height: CGFloat!
    weak var delegate: PageViewControllerDelegate?
    weak var parentController: ManagePageViewController!
    var recognizer = GestureRecognizerModel()
    var touchTypes = [UITouch.TouchType.pencil.rawValue as! NSNumber, UITouch.TouchType.direct.rawValue as! NSNumber]
    
    var transformview: TransformView!
    func generate_transformview(lasso: [CGPoint]) {
        
        guard let segmentmap = drawboardview.segmentmap,
            let segmentdatabase = drawboardview.segmentdatabase else {
            print("has not been loaded")
            return
        }
        let stroke_uuids = segmentmap.find_curves_in_lasso(lasso: lasso)
        
        transformview = TransformView(frame: drawboardview.frame)
        
        for stroke_uuid in stroke_uuids {
            let curve = Curve(uuid: stroke_uuid)
            curve.segments = segmentmap.get_segments_from_table(stroke_uuid: stroke_uuid)
            transformview.curves.append(curve)
        }
        for stroke_uuid in stroke_uuids {
            segmentmap.removeStroke(stroke_uuid: stroke_uuid)
            segmentdatabase.removeStroke(stroke_uuid: stroke_uuid)
        }
        transformview.lasso = lasso
        
        if let segmentmap = drawboardview.segmentmap {
            transformview.curves.sort {
                segmentmap.curve_array.getIndex(uuid: $0.uuid) < segmentmap.curve_array.getIndex(uuid: $1.uuid)
            }
        }
        
        
        let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(recognizer:)))
        recognizer.allowedTouchTypes = touchTypes
        recognizer.delegate = self
        transformview.isUserInteractionEnabled = true
        transformview.addGestureRecognizer(recognizer)
        transformview.backgroundColor = .clear
        transformview.tag = 0xDEADBEEF
        
        drawboardview.addSubview(transformview)
        if scrollview.zoomScale > 2 {
            transformview.layer.contentsScale = scrollview.zoomScale
        } else {
            transformview.layer.contentsScale = 2
        }
        drawboardview.setNeedsDisplay()
        transformview.setNeedsDisplay()
        transformview.drawLasso()
    }
    
    @IBAction func handlePan(recognizer:UIPanGestureRecognizer) {
        var translation = recognizer.translation(in: self.view)
        translation = CGPoint(x: translation.x / scrollview.zoomScale,
                              y: translation.y / scrollview.zoomScale)
        if let view = recognizer.view {
            view.center = CGPoint(x:view.center.x + translation.x,
                                  y:view.center.y + translation.y)
        }
        recognizer.setTranslation(CGPoint.zero, in: self.view)
    }
    
    var permission: Int!
    var notebook_uuid: String!
    var notebook: NotebookDocument!
    var page: NotebookPage!
    var pageIndex: Int!
    var page_uuid: String!
    var sqlitemanager = SQLiteManager.sharedInstance
    var page_socket: SocketIOClient! = SocketIOManager.sharedInstance.page_socket
    var type: NotebookType!
    var savedOperations: [Operation] = []
    var undoOperations: [Operation] = []
    
    // viewdidload only called once for each view, this produce problems
    override func viewDidAppear(_ animated: Bool) {
        
        print("did appear", drawactiveview.gestureRecognizers)
        print("notebook type is \(type)")
        
        super.viewDidAppear(animated)
        
        // ERROR OCCURED: NOTEBOOK SOCKET MAY NOT BE CONNECTED HERE, IN THAT CASE, IT WILL NOT BE LOADED
        if connected {
            
            self.delegate?.ConnectionStatusNeedsUpdate(text: "Page Loading...")
            self.page_socket.disconnect()
            
            self.page_socket.on(clientEvent: .connect) { data, ack in
                self.delegate?.ConnectionStatusNeedsUpdate(text: "Will Join Room")
                self.page_socket.emit("join_page_room", self.notebook_uuid, self.page_uuid)
            }

            self.page_socket.connect(timeoutAfter: 1) {
                self.delegate?.ConnectionStatusNeedsUpdate(text: "Page Fail to Connect")
            }
            
            page_socket.on("joined_room") { data, ack in
                guard let page_uuid = data[0] as? String,
                    let notebook_uuid = self.notebook_uuid,
                    let database = SegmentDatabase(page: self.page),
                    page_uuid == self.page_uuid else { return }
                print("send join_page request")
                let segment_dict = database.get_all_segment_uuids()
                AF.request(baseURL+"join_page", method: .post, parameters: ["notebook_uuid": notebook_uuid, "page_uuid": page_uuid, "segment_dict": segment_dict], encoding: JSONEncoding.default).response { response in
                    
                    do {
                        let json = JSON(response.data)
                        var maprows: [MapRow] = []
                        for row in json["new"].arrayValue {
                            let segment_string = try row["segment"].stringValue
                            let segment_data = Data(segment_string.utf8)
                            let decoder = JSONDecoder()
                            let segment = try decoder.decode(StrokeSegment.self, from: segment_data)
                            let maprow = MapRow(tile: Tile(r: row["tile"]["r"].intValue,
                                                           c: row["tile"]["c"].intValue),
                                                segment: segment,
                                                curve_uuid: row["curve_uuid"].stringValue,
                                                erased: row["erased"].boolValue)
                            maprows.append(maprow)
                        }
                        database.addRows(rows: maprows)
                        
                        if let deleted_segments = json["deleted"].arrayObject as? [String] {
                            database.removeSegments(segments: deleted_segments)
                        }
                        
                        // whether erased should be reversed
                        if var erased_dict = json["different"].dictionaryObject as? [String: Bool] {
                            database.updateSegmentsErased(erased_dict: erased_dict)
                        }
                    } catch {
                        print("fail to load maprows")
                    }
                    
                    
                    // initialize page
                    self.drawboardview.segmentdatabase = database
                    self.recognizer.addTarget(self, action: #selector(self.strokeUpdated(_:)))
                    self.recognizer.allowedTouchTypes = self.touchTypes
                    self.recognizer.brush = self.brush
                    self.recognizer.delegate = self
                    self.drawactiveview.addGestureRecognizer(self.recognizer)
                    
                    let frame = self.drawboardview.frame
                    DispatchQueue.global(qos: .background).async {
                        self.loadSegment(frame: frame) {
                            self.drawboardview.setNeedsDisplay()
                            self.backgroundview.pdfpage = self.page.pdfpage
                            self.backgroundview.setNeedsDisplay()
                            self.delegate?.BrushSelectionNeedsUpdate()
                            self.delegate?.ConnectionStatusNeedsUpdate(text: "Page Loaded")
                        }
                    }
                    
                }
            }

            page_socket.on("draw") { data, ack in
                print("draw received")
                if let array = data[0] as? [Any] {
                    if let page_uuid = array[1] as? String,
                        page_uuid == self.page_uuid,
                        let codedData = array[0] as? Data {
                        let decoder = JSONDecoder()
                        if let stroke = try? decoder.decode(Stroke.self, from: codedData) {
                            let curve = Stroke_to_Curve(stroke: stroke)
                            if let rows = self.drawboardview.segmentmap?.addCurve(curve: curve) {
                                self.drawboardview.segmentdatabase?.addRows(rows: rows)
                                self.drawactiveview.activeStroke = nil
                                self.drawactiveview.setNeedsDisplay()
                                self.drawboardview.setNeedsDisplay()
                            } else {
                                print("failed loading rows")
                            }
                        } else {
                            print("failed loading curve")
                        }
//                        if let rows = try? decoder.decode([MapRow].self, from: codedData) {
//                            for row in rows {
//                                self.drawboardview.segmentmap?.addRow(segment: row.segment, tile: row.tile, erased: false)
//                            }
//                            self.drawboardview.segmentdatabase?.addRows(rows: rows)
//                            self.drawactiveview.activeStroke = nil
//                            self.drawactiveview.setNeedsDisplay()
//                            self.drawboardview.setNeedsDisplay()
//                        } else {
//                            print("failed loading curve")
//                        }
                    }
                }
            }
            
            page_socket.on("erase") { data, ack in
                print("erase received")
                if let array = data[0] as? [Any] {
                    if let page_uuid = array[1] as? String,
                        page_uuid == self.page_uuid,
                        let segments = array[0] as? [String] {
                        for segment in segments {
                            self.drawboardview.segmentmap?.updateSegmentErased(segment_uuid: segment, erased: true)
                        }
                        self.drawboardview.segmentdatabase?.updateSegmentsErased(segments: segments, erased: true)
                    }
                    self.drawboardview.setNeedsDisplay()
                }
            }
            
            page_socket.on("lasso") { data, ack in
                let decoder = JSONDecoder()
                if let dict = data[0] as? [Any],
                    let page_uuid = dict[2] as? String,
                    self.page_uuid == page_uuid,
                    let maprowData = dict[0] as? Data,
                    let removedCurves = dict[1] as? [String],
                    let maprows = try? decoder.decode([MapRow].self, from: maprowData) {
                    for curve in removedCurves {
                        self.drawboardview.segmentmap?.removeStroke(stroke_uuid: curve)
                        self.drawboardview.segmentdatabase?.removeStroke(stroke_uuid: curve)
                    }
                    for maprow in maprows {
                        self.drawboardview.segmentmap?.addRow(segment: maprow.segment,
                                                              tile: maprow.tile, erased: maprow.erased)
                        self.drawboardview.segmentdatabase?.addRow(row: maprow)
                    }
                }
                self.drawboardview.setNeedsDisplay()
            }
        }
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.delegate?.BrushSelectionNeedsUpdate()
        
        scrollview.panGestureRecognizer.allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber]
        scrollview.panGestureRecognizer.minimumNumberOfTouches = 1
        scrollview.backgroundColor = .white
        
        // ALERT: IF HEIGHT IS SMALLER THAN HEIGHT OF SCROLLVIEW, THE VIEW CAN STILL SCROLL WHEN MINIMIZE, THIS IS JUST A QUICK FIX, BUT DID NOT KNOW EXACTLY WHY
        // SOLVED: BEST SOLUTION IS JUST SET CONSTRAINT, SO THAT WHEN ZOOMSCALE IS ONE, THE PAGE JUST FIT INTO THE SCREEN
        var mediaBox = page.pdfpage.getBoxRect(.mediaBox)
        backgroundWidthConstraint.constant = mediaBox.width
        backgroundHeightConstraint.constant = mediaBox.height
        backgroundview.frame = mediaBox
        
        backgroundview.layer.shadowColor = UIColor.black.cgColor
        backgroundview.layer.shadowOpacity = 0.5
        backgroundview.layer.shadowOffset = .zero
        backgroundview.layer.shadowRadius = 5
        
        let background_frame = backgroundview.frame
        drawboardview = DrawBoardView(frame: background_frame)
        drawboardview.brush = brush
        drawboardview.tempCurves = []
        backgroundview.addSubview(drawboardview)
        drawboardview.delegate = self
        let drawboard_frame = drawboardview.frame
        drawactiveview = DrawActiveView(frame: drawboard_frame)
        drawboardview.addSubview(drawactiveview)
        drawactiveview.delegate = self
        drawactiveview.brush = brush
        
        if type == .client {
            recognizer.addTarget(self, action: #selector(strokeUpdated(_:)))
            recognizer.allowedTouchTypes = touchTypes
            recognizer.brush = brush
            recognizer.delegate = self
            drawactiveview.addGestureRecognizer(recognizer)
        }
        
        drawactiveview.backgroundColor = .clear
        drawboardview.backgroundColor = .clear
        
        if type == .client {
            drawboardview.segmentdatabase = SegmentDatabase(page: page)
            DispatchQueue.global(qos: .background).async {
                self.loadSegment(frame: drawboard_frame) {
                    self.drawboardview.setNeedsDisplay()
                    self.backgroundview.pdfpage = self.page.pdfpage
                    self.backgroundview.setNeedsDisplay()
                    self.delegate?.BrushSelectionNeedsUpdate()
                }
            }
        }
        
        if let tempPdfdocument = CGPDFDocument(page.page_path.appendingPathComponent("flatten.pdf") as CFURL) {
            let tempPdfpage = tempPdfdocument.page(at: 1)
            backgroundview.pdfpage = tempPdfpage
        } else {
            backgroundview.pdfpage = page.pdfpage
        }
    }
    
    func loadSegment(frame: CGRect, completion: @escaping () -> Void) {
        if let segmentdatabase = drawboardview.segmentdatabase {
            print("is segmentdatabase")
            self.drawboardview.segmentmap = StrokeSegmentMap(segmentdatabase: segmentdatabase)
        } else {
            print("no segmentdatabase")
            self.drawboardview.segmentmap = StrokeSegmentMap(width: frame.width, height: frame.height)
        }
        //ALERT: segmentmap is not nil here, so curve will be added to segmentmap, so tempCurves will not be updated, but is it plausible?
        if let tempCurves = self.drawboardview.tempCurves {
            for tempCurve in tempCurves {
                if let rows = self.drawboardview.segmentmap?.addCurve(curve: tempCurve) {
                    for row in rows {
                        self.drawboardview.segmentdatabase?.addRow(row: row)
                    }
                }
            }
        }
        self.drawboardview.tempCurves = nil
        DispatchQueue.main.async {
            completion()
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        var size = view.bounds.size
        size.height -= topview.bounds.height
        print("topview", topview.bounds.height)
        
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
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("view1 will disappear")
        if type != .client {
            page_socket.removeAllHandlers()
            page_socket.disconnect()
            drawactiveview.gestureRecognizers?.forEach(drawactiveview.removeGestureRecognizer)
        }
        if let segmentmap = drawboardview.segmentmap,
            let pages_uuid = notebook.pages_uuid,
            pages_uuid.contains(page_uuid) {
            DrawImagePDF(segmentmap: segmentmap)
        }
    }
    
    var index_to_delete: [Int] = []
    var strokes_to_delete: [String] = []
    
    var all_erased_segments: [StrokeSegment]?
    @objc func strokeUpdated(_ strokeGesture: GestureRecognizerModel) {
        
        if brush.type == .eraser && strokeGesture.state == .began {
            all_erased_segments = []
        }

        drawactiveview.state = strokeGesture.state
        
        if brush.type == .eraser {
            let points = strokeGesture.stroke.Points
            if points.count >= 2 {
                let p1 = points[points.count - 2].location
                let p2 = points[points.count - 1].location
                if !(p1 == p2) {
                    if let segmentdatabase = drawboardview.segmentdatabase,
                        let segmentmap = drawboardview.segmentmap {
                        let result = segmentmap.erase_segments(A: p1, B: p2, width: strokeGesture.stroke.width)
                        let erased_segments = result.0
                        // ALERT: Can be deleted
//                        if type == .client {
//                            segmentdatabase.updateSegmentsErased(segments: erased_segments.map { $0.segment_uuid }, erased: true)
//                        }
                        segmentdatabase.updateSegmentsErased(segments: erased_segments.map { $0.segment_uuid }, erased: true)
                        if erased_segments.count > 0 {
                            if let rect = result.1 {
                                let adjustedRect = CGRect(x: rect.minX - 10,
                                                          y: rect.minY - 10,
                                                          width: (rect.maxX - rect.minX) + 20,
                                                          height: (rect.maxY - rect.minY) + 20)
                                print("a86 \(rect)")
                                self.drawboardview.setNeedsDisplay(adjustedRect)
                            }
                            all_erased_segments?.append(contentsOf: erased_segments)
                        }
                    }
                }
            }
        }
        
        drawactiveview.activeStroke = strokeGesture.stroke
        drawactiveview.setNeedsDisplay()
        
        if strokeGesture.state == .ended {
            // test here
            switch brush.type {
            case .pen:
                break
            case .highlighter:
                break
            case .lasso:
                let lasso = drawactiveview.activeStroke?.Points.map {
                    $0.location
                }
                drawactiveview.activeStroke = nil
                drawactiveview.setNeedsDisplay()
                generate_transformview(lasso: lasso!)
            case .eraser:
                if type == .client {
                    let operation = EraseOperation(segments: all_erased_segments!)
                    undoOperations.removeAll()
                    savedOperations.append(operation)
                } else {
                    if let all_erased_segments = all_erased_segments {
                        let segments = all_erased_segments.map { $0.segment_uuid }
//                        page_socket.emit("erase_segments", segments, notebook_uuid, page_uuid)
                        page_socket.emitWithAck("erase_segments", segments, notebook_uuid, page_uuid).timingOut(after: 1) { ack in
                            if ack.count > 0 && ack[0] as? String == SocketAckStatus.noAck.rawValue {
                                for segment in segments {
                                    self.drawboardview.segmentmap?.updateSegmentErased(segment_uuid: segment, erased: false)
                                }
                                self.drawboardview.segmentdatabase?.updateSegmentsErased(
                                    segments: segments, erased: false)
                                print("erase canceled")
                                self.drawboardview.setNeedsDisplay()
                            }
                        }
                    }
                }
                all_erased_segments = nil
                drawactiveview.activeStroke = nil
                drawactiveview.setNeedsDisplay()
            }
        }
    }
}

extension PageViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        print("a88 enter")
        if let recognizer = gestureRecognizer as? GestureRecognizerModel {
            print("a88 first")
            if drawboardview.segmentmap == nil && (brush.type == .eraser || brush.type == .lasso) {
                print("a88 haven't been loaded")
                return false
            }
        }
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if transformview == nil {
            return true
        }
        var point = touch.location(in: drawboardview)
        let origin = transformview.frame.origin
        point.x -= origin.x
        point.y -= origin.y
        print(point)
        if let segmentmap = drawboardview.segmentmap,
            let segmentdatabase = drawboardview.segmentdatabase {
            if segmentmap.check_point_in_lasso(point: point, lasso: transformview.lasso) {
                print("point in lasso")
                return true
            } else {
                print("point not in lasso")
                var removedCurves = [Curve]()
                var newCurves = [Curve]()
                var removedCurveUUID = [String]()
                var newRows = [MapRow]()
                for curve in transformview.curves {
                    print("first color \(curve.color)")
                    if curve.segments.count > 0 {
                        let originalCurve = curve.copy() as! Curve
                        curve.convert(dx: transformview.frame.origin.x, dy: transformview.frame.origin.y)
                        removedCurves.append(originalCurve)
                        removedCurveUUID.append(originalCurve.uuid)
                        newCurves.append(curve)
                        let rows = segmentmap.addCurve(curve: curve)
                        for row in rows {
                            segmentdatabase.addRow(row: row)
                            newRows.append(row)
                        }
                        print("after color \(curve.color)")
                    }
                    let operation = LassoOperation(removedCurves: removedCurves,
                                                   newCurves: newCurves)
                    undoOperations.removeAll()
                    savedOperations.append(operation)
                }
                
                let encoder = JSONEncoder()
                let data = try! encoder.encode(newRows)
//                page_socket.emit("lasso_ended", data, removedCurveUUID, notebook_uuid, page_uuid)
                if type == .server {
                    page_socket.emitWithAck("lasso_ended", data, removedCurveUUID, notebook_uuid, page_uuid).timingOut(after: 1) { ack in
                        if ack.count > 0 && ack[0] as? String == SocketAckStatus.noAck.rawValue {
                            for newCurve in newCurves {
                                self.drawboardview.segmentmap?.removeStroke(stroke_uuid: newCurve.uuid)
                                self.drawboardview.segmentdatabase?.removeStroke(stroke_uuid: newCurve.uuid)
                            }
                            for removedCurve in removedCurves {
                                if let rows = self.drawboardview.segmentmap?.addCurve(curve: removedCurve) {
                                    for row in rows {
                                        self.drawboardview.segmentdatabase?.addRow(row: row)
                                    }
                                }
                            }
                            self.drawboardview.setNeedsDisplay()
                        }
                    }
                }
                
                transformview.removeFromSuperview()
                transformview = nil
                
                drawboardview.setNeedsDisplay()
                return false
            }
        }
        return false
    }
}

extension PageViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return backgroundview
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if scrollView.zoomScale > 2 {
            drawboardview.layer.contentsScale = scrollView.zoomScale
            backgroundview.layer.contentsScale = scrollView.zoomScale
            drawactiveview.layer.contentsScale = scrollView.zoomScale
        } else {
            drawboardview.layer.contentsScale = 2
            backgroundview.layer.contentsScale = 2
            drawactiveview.layer.contentsScale = 2
        }
        drawboardview.setNeedsDisplay()
        backgroundview.setNeedsDisplay()
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        var size = view.bounds.size
        // ALERT: THIS DOES WORK, BUT DID NOT KNOW WHY, TRY TO FIND A FUNCTION TO CALCULATE THE ADJUSTION OF SIZE
        size.height -= topview.bounds.height
        let offsetX = max((size.width - scrollView.contentSize.width) * 0.5, 0)
        let offsetY = max((size.height - scrollView.contentSize.height) * 0.5, 0)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: 0, right: 0)
    }
}

extension PageViewController: DrawBoardViewDelegate {
     func finishDraw() {
        drawactiveview.activeStroke = nil
        drawactiveview.setNeedsDisplay()
    }
}

extension PageViewController: DrawActiveViewDelegate {
    func lastDrawFinish() {
        drawactiveview.state = UIGestureRecognizer.State.began
        if brush.type == .pen || brush.type == .highlighter,
            let stroke = drawactiveview.activeStroke {
            let curve = Stroke_to_Curve(stroke: stroke)
            if type == NotebookType.client {
                let t1 = CFAbsoluteTimeGetCurrent()
                if let segmentmap = drawboardview.segmentmap,
                    let segmentdatabase = drawboardview.segmentdatabase {
                    let rows = segmentmap.addCurve(curve: curve)
                    drawboardview.setNeedsDisplay()
                    drawactiveview.activeStroke = nil
                    drawactiveview.setNeedsDisplay()
                    let operation = DrawOperation(curve: curve.copy() as! Curve)
                    undoOperations.removeAll()
                    savedOperations.append(operation)
                    print("will add rows")
                    
                    DispatchQueue.main.async {
                        segmentdatabase.addRows(rows: rows)
                    }
                    
                } else {
                    drawboardview.tempCurves!.append(curve)
                }
            } else {
                if let segmentmap = drawboardview.segmentmap,
                    let segmentdatabase = drawboardview.segmentdatabase {
                    let rows = segmentmap.addCurve(curve: curve)
                    drawboardview.setNeedsDisplay()
                    drawactiveview.activeStroke = nil
                    drawactiveview.setNeedsDisplay()
                    
                    DispatchQueue.main.async {
                        segmentdatabase.addRows(rows: rows)
                        let encoder = JSONEncoder()
//                        let data = try! encoder.encode(rows)
                        let data = try! encoder.encode(stroke)
                        //ALERT: WHAT WILL HAPPEN IF SERVER RECEIVED DATA AFTER 1 SECOND?
                        //add stroke first, if emit failed, remove it from database
                        self.page_socket.emitWithAck("stroke_ended", data, self.notebook.notebook_uuid, self.page.page_uuid).timingOut(after: 1) { ack in
                            if ack.count > 0 && ack[0] as? String == SocketAckStatus.noAck.rawValue {
                                segmentmap.removeStroke(stroke_uuid: curve.uuid)
                                segmentdatabase.removeStroke(stroke_uuid: curve.uuid)
                                self.drawboardview.setNeedsDisplay()
                            }
                        }
                    }
                    
                }
            }
        }
    }
}

// MARK: - Draw Page
extension PageViewController {
    /// make sure segmentmap is loaded before call the function
    
    func DrawImagePDF(segmentmap: StrokeSegmentMap) {
        DrawImage(segmentmap: segmentmap)
        DrawPDF(segmentmap: segmentmap)
    }
    
    func DrawImage(segmentmap: StrokeSegmentMap) -> URL? {
        let pdfpage = page.pdfpage
        let pageFrame = pdfpage.getBoxRect(.mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageFrame.size)
        let image = renderer.image { context in
            let ctx = context.cgContext
            
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: pageFrame.size))
            
            ctx.saveGState()
            ctx.scaleBy(x: 1, y: -1)
            ctx.translateBy(x: 0, y: -pageFrame.size.height)
            ctx.drawPDFPage(pdfpage)
            ctx.restoreGState()
            
            for stroke in segmentmap.get_all_strokes() {
                let segments = segmentmap.get_segments_from_table(stroke_uuid: stroke)
                if !segments.isEmpty {
                    let color = segments[0].color
                    var red: CGFloat = 0
                    var green: CGFloat = 0
                    var blue: CGFloat = 0
                    var alpha: CGFloat = 0
                    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                    
                    if alpha < 1 {
                        let path = UIBezierPath()
                        let firstSegment = segments[0]
                        let width = distance(firstSegment.start_lower_point,
                                             firstSegment.start_upper_point)
                        let firstPoint = getMidPoint(firstPoint: firstSegment.start_lower_point,
                                                     secondPoint: firstSegment.start_upper_point)
                        for segment in segments {
                            let startPoint = getMidPoint(firstPoint: segment.start_upper_point,
                                                         secondPoint: segment.start_lower_point)
                            let endPoint = getMidPoint(firstPoint: segment.end_lower_point,
                                                       secondPoint: segment.end_upper_point)
                            path.move(to: startPoint)
                            path.addLine(to: endPoint)
                        }
                        path.lineWidth = width
                        path.lineCapStyle = .round
                        path.lineJoinStyle = .round
                        color.setStroke()
                        path.stroke()
                    } else {
                        for segment in segments {
                            color.setFill()
                            segment.paths[0].fill()
                        }
                    }
                }
            }
        }
        let data = image.pngData()
        let destinationPath = page.page_path.appendingPathComponent("image.png")
        try? data?.write(to: destinationPath)
        print("a445 \(destinationPath)")
        return destinationPath
    }
    
    func DrawPDF(segmentmap: StrokeSegmentMap) -> URL? {
        let pdfpage = page.pdfpage
        let destinationPath = page.page_path.appendingPathComponent("flatten.pdf").path
        UIGraphicsBeginPDFContextToFile(destinationPath, CGRect.zero, nil)
        let pageFrame = pdfpage.getBoxRect(.mediaBox)
        UIGraphicsBeginPDFPageWithInfo(pageFrame, nil)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        
        ctx.saveGState()
        
        ctx.scaleBy(x: 1, y: -1)
        
        ctx.translateBy(x: 0, y: -pageFrame.size.height)
        ctx.drawPDFPage(pdfpage)
        ctx.restoreGState()

        for stroke in segmentmap.get_all_strokes() {
            let segments = segmentmap.get_segments_from_table(stroke_uuid: stroke)
            if !segments.isEmpty {
                let color = segments[0].color
                var red: CGFloat = 0
                var green: CGFloat = 0
                var blue: CGFloat = 0
                var alpha: CGFloat = 0
                color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                
                if alpha < 1 {
                    let path = UIBezierPath()
                    let firstSegment = segments[0]
                    let width = distance(firstSegment.start_lower_point,
                                         firstSegment.start_upper_point)
                    let firstPoint = getMidPoint(firstPoint: firstSegment.start_lower_point,
                                                 secondPoint: firstSegment.start_upper_point)
                    for segment in segments {
                        let startPoint = getMidPoint(firstPoint: segment.start_upper_point,
                                                     secondPoint: segment.start_lower_point)
                        let endPoint = getMidPoint(firstPoint: segment.end_lower_point,
                                                   secondPoint: segment.end_upper_point)
                        path.move(to: startPoint)
                        path.addLine(to: endPoint)
                    }
                    path.lineWidth = width
                    path.lineCapStyle = .round
                    path.lineJoinStyle = .round
                    color.setStroke()
                    path.stroke()
                } else {
                    for segment in segments {
                        color.setFill()
                        segment.paths[0].fill()
                    }
                }
            }
        }
        
        UIGraphicsEndPDFContext()
        return URL(string: destinationPath)!
    }
}
