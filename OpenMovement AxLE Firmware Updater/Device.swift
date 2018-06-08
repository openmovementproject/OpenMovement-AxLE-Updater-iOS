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
    let peripheral:CBPeripheral
    var mac:String?
    var txUart:CBCharacteristic?
    
    init(peripheral:CBPeripheral) {
        self.peripheral = peripheral
    }
}
