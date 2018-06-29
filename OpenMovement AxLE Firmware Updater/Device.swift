//
//  Device.swift
//  OpenMovement AxLE Firmware Updater
//
//  Created by Gerard Wilkinson (PGR) on 08/06/2018.
//  Copyright © 2018 Gerard Wilkinson. All rights reserved.
//

import Foundation
import CoreBluetooth

class Device
{
    let peripheral:CBPeripheral!
    var mac:String?
    var version:String?
    var rxUart:CBCharacteristic?
    var txUart:CBCharacteristic?
    
    init(peripheral:CBPeripheral) {
        self.peripheral = peripheral
    }
    
    // MOCK
    init() {
        mac = String(format: "%06X%06X", arc4random_uniform(UInt32(UInt16.max)), arc4random_uniform(UInt32(UInt16.max)))
        version = "1.6"
        
        peripheral = nil
    }
}
