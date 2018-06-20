//
//  MultipeerDataParser.swift
//  MPCRevisited
//
//  Created by doxie on 12/21/17.
//  Copyright © 2017 Appcoda. All rights reserved.
//

import Foundation
import MultipeerConnectivity

public enum MultipeerDataType: String {

    case groupInfo

    case message
}

class MultipeerData: NSObject, NSCoding {

    var dataType: MultipeerDataType
    var data: NSCoding?

    init(data: NSCoding?, type: MultipeerDataType) {
        self.data = data
        self.dataType = type
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.dataType.rawValue, forKey: "dataType")
        aCoder.encode(self.data, forKey: "data")
    }

    required init?(coder aDecoder: NSCoder) {
        self.dataType = MultipeerDataType(rawValue: aDecoder.decodeObject(forKey: "dataType") as! String)!
        self.data = aDecoder.decodeObject(forKey: "data") as? NSCoding
    }
}

class MultipeerTransportData: NSObject, NSCoding {

    var needForward: Bool = false
    var forwardList: [MCPeerID]?
    var sender: MCPeerID!
    var data: MultipeerData
    var isUpdateGroupInfo: Bool = false

    init(data: MultipeerData, sender: MCPeerID) {
        self.data = data
        self.sender = sender
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(needForward, forKey: "needForward")
        aCoder.encode(forwardList, forKey: "forwardList")
        aCoder.encode(sender, forKey: "sender")
        aCoder.encode(data, forKey: "data")
        aCoder.encode(isUpdateGroupInfo, forKey: "isUpdateGroupInfo")
    }

    required init?(coder aDecoder: NSCoder) {
        self.needForward = aDecoder.decodeBool(forKey: "needForward")
        self.forwardList = aDecoder.decodeObject(forKey: "forwardList") as? [MCPeerID]
        self.sender = aDecoder.decodeObject(forKey: "sender") as! MCPeerID
        self.data = aDecoder.decodeObject(forKey: "data") as! MultipeerData
        self.isUpdateGroupInfo = aDecoder.decodeBool(forKey: "isUpdateGroupInfo")
    }

}

class MultipeerDataParser {

}
