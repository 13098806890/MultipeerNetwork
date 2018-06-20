//
//  MultipeerNetWorkNode.swift
//  TestMultipeerConnectivity
//
//  Created by doxie on 12/20/17.
//  Copyright © 2017 Xie. All rights reserved.
//

import MultipeerConnectivity

protocol MultipeerBuildUpNetWorkDelegate {

    func foundPeer()

    func lostPeer()

    func invitationWasReceived(fromPeer: String)

    func connectedWithPeer(name: String)
}

protocol MultipeerNetWorkNodeDelegate: MultipeerBuildUpNetWorkDelegate {

    func handle(data: MultipeerData, from: String)

    func updateGroupInfo(group: [String])

}

class MultipeerNetWorkNode: NSObject, MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate {

    fileprivate var session: MCSession!

    fileprivate var peer: MCPeerID!

    fileprivate var browser: MCNearbyServiceBrowser?

    fileprivate var advertiser: MCNearbyServiceAdvertiser?

    fileprivate var foundPeers = [MCPeerID]()

    fileprivate var groupInfo = [MCPeerID]()

    internal var invitationHandler: ((Bool) -> Void)!

    var delegate: MultipeerNetWorkNodeDelegate?

    var isMaster: Bool = false

    init(_ name: String = UIDevice.current.name) {
        super.init()
        peer = MCPeerID(displayName: name)
        session = MCSession(peer: peer)
        session.delegate = self
    }

    func createBrowser(_ serviceType: String) {
        foundPeers = [MCPeerID]()
        groupInfo = [MCPeerID]()
        browser = MCNearbyServiceBrowser(peer: peer, serviceType: serviceType)
        browser?.delegate = self
        startBrowser()
    }

    fileprivate func startBrowser() {
        browser?.startBrowsingForPeers()
    }

    fileprivate func stopBrowser() {
        browser?.stopBrowsingForPeers()
    }

    func createAdvertiser(_ serviceType: String) {
        advertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        startAdvertiser()
    }

    fileprivate func startAdvertiser() {
        advertiser?.startAdvertisingPeer()
    }

    fileprivate func stopAdvertiser() {
        advertiser?.stopAdvertisingPeer()
    }

    //MARK : - MCNearbyServiceBrowserDelegate
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        foundPeers.append(peerID)
        delegate?.foundPeer()
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        for (index, aPeer) in foundPeers.enumerated() {
            if aPeer == peerID {
                foundPeers.remove(at: index)
                break
            }
        }
        delegate?.lostPeer()
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print(error.localizedDescription)
    }

    //MARK : MCNearbyServiceAdvertiserDelegate
    internal func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Swift.Void) {
        self.invitationHandler = { (invitation: Bool) -> Swift.Void  in
            invitationHandler(invitation, self.session)
        }
        delegate?.invitationWasReceived(fromPeer: peerID.displayName)
    }

    internal func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print(error.localizedDescription)
    }

    //MARK : MCSessionDelegate
    internal func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case MCSessionState.connected:
            print("Connected to session: \(session)")
            if isMaster {
                updateGroupInfo()
            }
            delegate?.connectedWithPeer(name: peerID.displayName)

        case MCSessionState.connecting:
            print("Connecting to session: \(session)")
        case MCSessionState.notConnected:
            if isMaster {
                updateGroupInfo()
            }
            print("Lost connection to session: \(session)")
        }
    }

    internal func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let transportData = NSKeyedUnarchiver.unarchiveObject(with: data) as! MultipeerTransportData
        handle(data: transportData)

    }

    internal func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) { }

    internal func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) { }

    internal func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { }
}

//transport layer
protocol MultipeerTransportDataDelegate {

    func sendTransportData(data transportData: MultipeerTransportData, toPeers targetPeer: [MCPeerID]) -> Bool

    func sendData(data: MultipeerData, toPeers: [MCPeerID]) -> Bool

    func handle(data transportData: MultipeerTransportData)

    func updateGroupInfo()
}

extension MultipeerNetWorkNode: MultipeerTransportDataDelegate {

    internal func sendTransportData(data transportData: MultipeerTransportData, toPeers targetPeer: [MCPeerID]) -> Bool {
        let dataToSend = NSKeyedArchiver.archivedData(withRootObject: transportData)
        // don't send message to self
        let peers = targetPeer.filter({ (peer) -> Bool in
            return !peer.isEqual(self.peer)
        })
        do {
            _ = try session.send(dataToSend, toPeers: peers, with:MCSessionSendDataMode.reliable)
        } catch {
            print(error)
            return false
        }

        return true
    }

    internal func sendData(data: MultipeerData, toPeers: [MCPeerID]) -> Bool {
        let transportData = MultipeerTransportData.init(data: data, sender: peer)
        if isMaster {
            if !sendTransportData(data: transportData, toPeers: toPeers) {

                return false
            }
        } else {
            transportData.needForward = true
            transportData.forwardList = toPeers
            if !sendTransportData(data: transportData, toPeers: [session.connectedPeers[0]]) {

                return false
            }
        }

        return true
    }

    internal func handle(data transportData: MultipeerTransportData) {
        if transportData.isUpdateGroupInfo {
        // if this message is to update group info message. then handle this message by this class. if not handler other message by the delegate.
            let data = transportData.data
            if data.dataType == MultipeerDataType.groupInfo {
                let groupInfo = transportData.forwardList
                self.groupInfo = groupInfo!
                delegate?.updateGroupInfo(group: peersDisplayNames(peerList: groupInfo!))
            }
        } else {
            if isMaster {
                if transportData.needForward {
                    if let forwardList = transportData.forwardList {
                        let forwardData = MultipeerTransportData.init(data: transportData.data, sender: transportData.sender)
                        if !(sendTransportData(data: forwardData, toPeers: forwardList)) {
                            //need to handle when send data failed.
                        }
                        if forwardList.contains(peer) {
                            delegate?.handle(data: transportData.data, from: transportData.sender.displayName)
                        }
                    }
                } else {
                    delegate?.handle(data: transportData.data, from: transportData.sender.displayName)
                }
            } else {
                delegate?.handle(data: transportData.data, from: transportData.sender.displayName)
            }
        }
    }

    internal func updateGroupInfo() {
        groupInfo = session.connectedPeers
        groupInfo.append(peer)
        let data = MultipeerData.init(data: nil, type: MultipeerDataType.groupInfo)
        let transportData = MultipeerTransportData.init(data: data, sender: peer)
        transportData.isUpdateGroupInfo = true
        transportData.forwardList = groupInfo
        self.delegate?.updateGroupInfo(group: peersDisplayNames(peerList: groupInfo))
        if !sendTransportData(data: transportData, toPeers: session.connectedPeers) {
           // handle error here
        }
    }

    internal func peersDisplayNames(peerList: [MCPeerID]) -> [String] {
        var groupNames = [String]()
        for peer in peerList {
            groupNames.append(peer.displayName)
        }

        return groupNames
    }

}

// method for user to use
protocol MultipeerNetWorkNodeCommunicationDelegate {

    func send(data: MultipeerData, toUsers: [String]) -> Bool

    func sendDataToAll(data: MultipeerData) -> Bool

    func invite(node: String, withContext: Data?, timeout: TimeInterval)

    var invitationHandler: ((Bool) -> Void)! {get}

    func disconnect()

    func nearbyUsers() -> [String]

    func joinedUsers() -> [String]
}

extension MultipeerNetWorkNode: MultipeerNetWorkNodeCommunicationDelegate {

    func send(data: MultipeerData, toUsers: [String]) -> Bool {
        let peersList = groupInfo.filter { (peer) -> Bool in
            return toUsers.contains(peer.displayName)
        }
        if peersList.count > 0 {
            return sendData(data: data, toPeers: peersList)
        }

        return false
    }

    func sendDataToAll(data: MultipeerData) -> Bool {
        let groupInfoExceptSelf = groupInfo.filter { (peer) -> Bool in
            return !peer.isEqual(self.peer)
        }
        if groupInfoExceptSelf.count > 0 {
            return sendData(data: data, toPeers: groupInfoExceptSelf)
        }
        
            return false
    }

    func invite(node: String, withContext: Data?, timeout: TimeInterval) {
        for peer in foundPeers {
            if node == peer.displayName {
                self.browser?.invitePeer(peer, to: session, withContext: withContext, timeout: timeout)
                break
            }
        }
    }

    func disconnect() {
        if !isMaster {
        self.session.disconnect()
        }
    }

    func nearbyUsers() -> [String] {
        return peersDisplayNames(peerList: foundPeers.filter({ (peer) -> Bool in
            return !self.session.connectedPeers.contains(peer)
        }))
    }

    func joinedUsers() -> [String] {
        return peersDisplayNames(peerList: session.connectedPeers)
    }

}
