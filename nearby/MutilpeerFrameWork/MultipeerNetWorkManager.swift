//
//  MultipeerNetWorkManager.swift
//  MicroStrategyMobileSDK
//
//  Created by doxie on 12/25/17.
//  Copyright © 2017 MicroStratgy Inc. All rights reserved.
//

import Foundation
import UIKit

class MultipeerNetWorkManager: MultipeerNetWorkNodeDelegate {

    static let manager = MultipeerNetWorkManager()
    var node = MultipeerNetWorkNode()
    var delegate: MultipeerBuildUpNetWorkDelegate?
    var isBrowserCreated = false
    var isAdvertiserCreated = false

    func createNetWork() {
        if !isBrowserCreated {
            node.delegate = self
            node.createBrowser("dossier")
            node.isMaster = true
        }
    }

    func searchNetWork() {
        if !isAdvertiserCreated {
            node.delegate = self
            node.createAdvertiser("dossier")
        }
    }

    func nearbyUsers() -> [String] {
        return node.nearbyUsers()
    }

    func joinedUsers() -> [String] {
        return node.joinedUsers()
    }

    func send(data: MultipeerData) {
        node.sendDataToAll(data: data)
    }

    // MARK: MultipeerNetWorkNodeDelegate
    func foundPeer() {
        delegate?.foundPeer()
    }

    func lostPeer() {
        delegate?.lostPeer()
    }

    func invitationWasReceived(fromPeer: String) {
        self.delegate?.invitationWasReceived(fromPeer: fromPeer)
    }

    func connectedWithPeer(name: String) {
        delegate?.connectedWithPeer(name: name)
    }

    func handle(data: MultipeerData, from: String) {
        switch data.dataType {
        case MultipeerDataType.message:
            NSLog("Multipeer Network Data Received: message")
            // Handle message

        case MultipeerDataType.groupInfo:
            NSLog("Multipeer Network Data Received: groupInfo")
            // Handle groupInfo
        default:
            NotificationCenter.default.post(name: Notification.Name(rawValue: data.dataType.rawValue), object: nil,
                                            userInfo: ["data": data.data])
        }
    }

    func updateGroupInfo(group: [String]) {
    }
}
