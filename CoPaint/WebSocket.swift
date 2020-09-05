//
//  WebSocket.swift
//  CoPaint
//
//  Created by 张睿杰 on 2020/9/5.
//  Copyright © 2020 张睿杰. All rights reserved.
//

import Foundation
import Starscream
import SwiftyJSON

internal class CoPaintWebSocket: WebSocketDelegate {
    let socket: WebSocket
    static public private(set) var shared: CoPaintWebSocket = CoPaintWebSocket()
    private var onTouch: ((Touch) -> Void)? = nil
    private var onEnter: (() -> Void)? = nil
    public var roomId: Int = 0
    public var paintingId: Int = 0
    public var touches: [Touch] = [] // touches already exist in the room
    
    
    private init() {
        let request = URLRequest(url: URL(string: "https://go.hqy.moe/ws/")!)
        self.socket = WebSocket(request: request)
        self.socket.delegate = self
        self.socket.connect()
            }
    
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        dump(event) 
        switch event {
        case .text(let str):
            let json = JSON.init(parseJSON: str)
            if json["room"].exists() {
                self.roomId = json["room"]["id"].int!
                self.paintingId = json["room"]["paintingId"].int!
                let touches = json["room"]["touches"].array
                for json in touches ?? [] {
                    self.touches.append(Touch(x: json["x"].int!, y: json["y"].int!, r: json["r"].int!, g: json["g"].int!,  b: json["b"].int!))
                }
                self.onEnter!()
            } else if json["x"].exists() {
                self.onTouch!(Touch(x: json["x"].int!, y: json["y"].int!, r: json["r"].int!, g: json["g"].int!,  b: json["b"].int!))
            }
        case .connected(_):
           break
        default:
            break
        }
    }
    
    public func create(paintingId: Int, completion: @escaping () -> Void, onTouch: @escaping (Touch) -> Void) {
        self.onTouch = onTouch
        self.onEnter = completion
        self.socket.write(string: "{\"type\":\"room\",\"data\":{\"operation\":\"create\", \"Id\": \(paintingId)}}", completion: nil)
    }
    
    public func join(roomId: Int, completion: @escaping () -> Void, onTouch: @escaping (Touch) -> Void) {
        self.onTouch = onTouch
        self.onEnter = completion
        self.socket.write(string: "{\"type\":\"room\",\"data\":{\"operation\":\"join\", \"Id\": \(roomId)}}", completion: nil)
    }
    
    public func exit() {
        self.socket.write(string: "{\"type\":\"room\",\"data\":{\"operation\":\"exit\"", completion: nil)
    }
    
    public func touch(x: Int, y: Int, r: Int, g: Int, b: Int) {
        self.socket.write(string: "{\"type\":\"event\", \"data\": {\"touch\": {\"x\": \(x), \"y\": \(y), \"r\": \(r), \"g\": \(g), \"b\": \(b)}}}", completion: nil)
    }
    
    
}

struct Touch {
    let x: Int
    let y: Int
    let r: Int
    let g: Int
    let b: Int
    
    init(x: Int, y: Int, r: Int, g: Int, b: Int) {
        self.x = x
        self.y = y
        self.r = r
        self.g = g
        self.b = b
    }
}
