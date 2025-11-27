//
//  File.swift
//  
//
//  Created by Matheus Gois on 22/10/21.
//

import Foundation
import LanScanInternal
import CoreGraphics

public struct LanDevice {
    public var id: UUID
    public var name: String?
    public var ipAddress: String
    public var mac: String
    public var brand: String
}

public protocol LanScannerDelegate: AnyObject {
    func lanScanHasUpdatedProgress(_ progress: CGFloat, address: String)
    func lanScanDidFindNewDevice(_ device: LanDevice)
    func lanScanDidFinishScanning()
}

public class LanScanner: NSObject {
    // MARK: - Properties
    public var scanner: LanScan?
    public weak var delegate: LanScannerDelegate?

    // MARK: - Init
    public init(delegate: LanScannerDelegate?) {
        self.delegate = delegate
        super.init()
        print("🧭 [LanScanner] init (delegate set: \(delegate != nil))")
    }

    // MARK: - Methods
    public func stop() {
        print("🛑 [LanScanner] Stop requested")
        scanner?.stop()
    }

    public func start() {
        print("🚀 [LanScanner] Start requested (reset scanner and begin)")
        scanner?.stop()
        scanner = LanScan(delegate: self)
        scanner?.start()
    }

    public func getCurrentWifiSSID() -> String? {
        print("📶 [LanScanner] getCurrentWifiSSID() → not implemented in wrapper")
        return nil // scanner?.getCurrentWifiSSID()
    }
}

extension LanScanner: LANScanDelegate {
    public func lanScanHasUpdatedProgress(_ counter: Int, address: String!) {
        let progress = CGFloat(counter) / CGFloat(MAX_IP_RANGE)
        let percent = Int((progress * 100).rounded())
        let addr = address ?? "-"
        print("📈 [LanScanner] Progress: \(percent)% @ \(addr)")
        delegate?.lanScanHasUpdatedProgress(progress, address: addr)
    }

    public func lanScanDidFindNewDevice(_ device: [AnyHashable : Any]!) {
        guard let device = device as? [AnyHashable: String] else { return }
        let found = LanDevice(
            id: UUID(),
            name: device[DEVICE_NAME],
            ipAddress: device[DEVICE_IP_ADDRESS] ?? "",
            mac: device[DEVICE_MAC] ?? "",
            brand: device[DEVICE_BRAND] ?? ""
        )
        let name = found.name ?? "Unknown"
        print("🔎 [LanScanner] Found device → \(name) [\(found.brand)] • IP: \(found.ipAddress) • MAC: \(found.mac)")
        delegate?.lanScanDidFindNewDevice(found)
    }

    public func lanScanDidFinishScanning() {
        print("✅ [LanScanner] Scanning finished")
        delegate?.lanScanDidFinishScanning()
    }
}
