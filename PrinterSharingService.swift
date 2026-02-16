import Foundation
import MultipeerConnectivity
import UIKit
import Combine

/// Roles for devices in the printer sharing network
enum AppRole: String, CaseIterable, Identifiable {
    case host = "Host"
    case client = "Cliente"
    
    var id: String { rawValue }
}

/// Manages MultipeerConnectivity session for sharing a Phomemo printer
/// across multiple devices on the local network.
///
/// - Host: Advertises availability and receives print jobs from clients,
///   then delegates to PhomemoDriver for BLE printing.
/// - Client: Browses for a nearby host and sends images for remote printing.
class PrinterSharingService: NSObject, ObservableObject {
    
    // MARK: - Published State
    
    @Published var role: AppRole = .host
    @Published var connectedPeers: [MCPeerID] = []
    @Published var statusMessage: String = "Idle"
    @Published var isConnected: Bool = false
    @Published var receivedImage: UIImage?
    @Published var remotePeerName: String?
    
    // MARK: - MultipeerConnectivity
    
    private let serviceType = "phomemo-share" // Max 15 chars, lowercase + hyphens
    private let myPeerID: MCPeerID
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    
    // MARK: - Init
    
    override init() {
        let deviceName = UIDevice.current.name
        self.myPeerID = MCPeerID(displayName: deviceName)
        super.init()
        
        self.session = MCSession(
            peer: myPeerID,
            securityIdentity: nil,
            encryptionPreference: .none
        )
        self.session.delegate = self
    }
    
    // MARK: - Public API
    
    /// Switch role and start the appropriate service
    func setRole(_ newRole: AppRole) {
        stop()
        role = newRole
        
        switch newRole {
        case .host:
            startHosting()
        case .client:
            startBrowsing()
        }
    }
    
    /// Host: Start advertising this device as a print relay
    func startHosting() {
        advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: nil,
            serviceType: serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        statusMessage = "Anunciando impressora..."
        print("[PrinterSharing] Host: Advertising started")
    }
    
    /// Client: Start looking for a nearby host
    func startBrowsing() {
        browser = MCNearbyServiceBrowser(
            peer: myPeerID,
            serviceType: serviceType
        )
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        statusMessage = "Procurando host..."
        print("[PrinterSharing] Client: Browsing started")
    }
    
    /// Tear down all services
    func stop() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
        session.disconnect()
        
        DispatchQueue.main.async {
            self.connectedPeers = []
            self.isConnected = false
            self.statusMessage = "Idle"
        }
        print("[PrinterSharing] Services stopped")
    }
    
    /// Client: Send an image to the connected host for printing
    func sendImageForPrint(_ image: UIImage) {
        guard !session.connectedPeers.isEmpty else {
            statusMessage = "Sem host conectado"
            print("[PrinterSharing] Client: No peers connected, cannot send")
            return
        }
        
        // Compress as JPEG for efficient transfer
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            statusMessage = "Erro ao comprimir imagem"
            return
        }
        
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            statusMessage = "Imagem enviada!"
            print("[PrinterSharing] Client: Sent \(data.count) bytes to \(session.connectedPeers.count) peer(s)")
        } catch {
            statusMessage = "Erro: \(error.localizedDescription)"
            print("[PrinterSharing] Client: Send failed: \(error)")
        }
    }
    
    deinit {
        stop()
    }
}

// MARK: - MCSessionDelegate

extension PrinterSharingService: MCSessionDelegate {
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.connectedPeers = session.connectedPeers
            self.isConnected = !session.connectedPeers.isEmpty
            
            switch state {
            case .connected:
                self.statusMessage = "Conectado: \(peerID.displayName)"
                print("[PrinterSharing] Peer connected: \(peerID.displayName)")
            case .connecting:
                self.statusMessage = "Conectando: \(peerID.displayName)..."
                print("[PrinterSharing] Peer connecting: \(peerID.displayName)")
            case .notConnected:
                if session.connectedPeers.isEmpty {
                    self.statusMessage = self.role == .host ? "Anunciando impressora..." : "Procurando host..."
                }
                print("[PrinterSharing] Peer disconnected: \(peerID.displayName)")
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Host receives image data from a client
        print("[PrinterSharing] Host: Received \(data.count) bytes from \(peerID.displayName)")
        
        guard let image = UIImage(data: data) else {
            print("[PrinterSharing] Host: Failed to decode image from received data")
            return
        }
        
        DispatchQueue.main.async {
            self.remotePeerName = peerID.displayName
            self.receivedImage = image
            print("[PrinterSharing] Host: Image decoded, triggering print")
        }
    }
    
    // Required but unused delegate methods
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate (Host)

extension PrinterSharingService: MCNearbyServiceAdvertiserDelegate {
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Auto-accept all incoming connections
        print("[PrinterSharing] Host: Auto-accepting invitation from \(peerID.displayName)")
        invitationHandler(true, session)
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("[PrinterSharing] Host: Failed to advertise: \(error)")
        DispatchQueue.main.async {
            self.statusMessage = "Erro ao anunciar"
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate (Client)

extension PrinterSharingService: MCNearbyServiceBrowserDelegate {
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        // Auto-invite discovered hosts
        print("[PrinterSharing] Client: Found host \(peerID.displayName). Auto-inviting...")
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
        
        DispatchQueue.main.async {
            self.statusMessage = "Host encontrado: \(peerID.displayName)"
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("[PrinterSharing] Client: Lost host \(peerID.displayName)")
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("[PrinterSharing] Client: Failed to browse: \(error)")
        DispatchQueue.main.async {
            self.statusMessage = "Erro ao procurar"
        }
    }
}
