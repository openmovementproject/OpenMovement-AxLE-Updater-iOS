//
//  ViewController.swift
//  OpenMovement AxLE Firmware Updater
//
//  Created by Gerard Wilkinson (PGR) on 08/06/2018.
//  Copyright © 2018 Gerard Wilkinson. All rights reserved.
//

import UIKit
import CoreBluetooth
import iOSDFULibrary
import SVProgressHUD

class ViewController: UITableViewController, CBCentralManagerDelegate, CBPeripheralDelegate, CBPeripheralManagerDelegate, LoggerDelegate, DFUServiceDelegate, DFUProgressDelegate {
    let AxLEDeviceName = "axLE-Band"
    let AxLEBootloaderDeviceName = "OM-DFU"
    
    let UartServiceUuid = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    let UartRxCharacUuid = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    let UartTxCharacUuid = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    let DeviceInformationServiceUuid = CBUUID(string: "0000180A-0000-1000-8000-00805f9b34fb")
    let SerialNumberCharacUuid = CBUUID(string: "00002A25-0000-1000-8000-00805f9b34fb")
    
    var axleCentralManger:CBCentralManager?
    
    var devices:[Device]
    var dfuQueue:[UUID]
    
    let firmware:DFUFirmware
    
    var currentController:DFUServiceController?
    
    required init?(coder aDecoder: NSCoder) {
        devices = []
        dfuQueue = []
        
        firmware = DFUFirmware(urlToZipFile: URL(fileURLWithPath: Bundle.main.path(forResource: "update-1.5", ofType: "zip")!))!
        
        super.init(coder: aDecoder)
        axleCentralManger = CBCentralManager(delegate: self, queue: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        SVProgressHUD.setDefaultMaskType(.black)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("CoreBluetooth BLE hardware is powered on and ready")
            axleCentralManger?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            break
        default:
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.name == AxLEDeviceName && !devices.contains(where: { (device) -> Bool in
            return device.peripheral.identifier == peripheral.identifier
        })
        {
            devices.append(Device(peripheral: peripheral))
            central.connect(peripheral, options: nil)
        }
        else if peripheral.name == AxLEBootloaderDeviceName
        {
            let initiator = DFUServiceInitiator(centralManager: axleCentralManger!, target: peripheral).with(firmware: firmware)
            initiator.logger = self
            initiator.delegate = self
            initiator.progressDelegate = self
            currentController = initiator.start()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if peripheral.name == AxLEDeviceName
        {
            peripheral.delegate = self
            peripheral.discoverServices([DeviceInformationServiceUuid, UartServiceUuid])
        }
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        // Not used
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if !(error != nil)
        {
            let infoService = peripheral.services?.first(where: { (s) -> Bool in return s.uuid == DeviceInformationServiceUuid })
            let uartService = peripheral.services?.first(where: { (s) -> Bool in return s.uuid == UartServiceUuid })
            
            if let si = infoService, let su = uartService
            {
                peripheral.discoverCharacteristics([SerialNumberCharacUuid], for: si)
                peripheral.discoverCharacteristics([UartTxCharacUuid], for: su)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if !(error != nil)
        {
            if service.uuid == DeviceInformationServiceUuid
            {
                let charc = service.characteristics?.first(where: { (c) -> Bool in return c.uuid == SerialNumberCharacUuid })
                peripheral.readValue(for: charc!)
            }
            
            if service.uuid == UartServiceUuid
            {
                let device = devices.first { (d) -> Bool in
                    return d.peripheral.identifier == peripheral.identifier
                }
                
                device?.txUart = service.characteristics?.first(where: { (c) -> Bool in return c.uuid == UartTxCharacUuid })
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if !(error != nil)
        {
            let device = devices.first { (d) -> Bool in
                return d.peripheral.identifier == peripheral.identifier
            }
            
            if dfuQueue.contains(peripheral.identifier)
            {
                dfuQueue.remove(at: dfuQueue.index(of: peripheral.identifier)!)
                device!.peripheral.writeValue("M".data(using: .utf8)!, for: device!.txUart!, type: .withoutResponse)
                device!.peripheral.writeValue("2".data(using: .utf8)!, for: device!.txUart!, type: .withoutResponse)
                device!.peripheral.writeValue("M".data(using: .utf8)!, for: device!.txUart!, type: .withoutResponse)
                device!.peripheral.writeValue("2".data(using: .utf8)!, for: device!.txUart!, type: .withoutResponse)
                device!.peripheral.writeValue("M".data(using: .utf8)!, for: device!.txUart!, type: .withoutResponse)
                device!.peripheral.writeValue("2".data(using: .utf8)!, for: device!.txUart!, type: .withoutResponse)
                
                let alert = UIAlertController(title: "WARNING", message: "You are about to update an AxLE. This will wipe all data! The device should have vibrated and flashed when selected.", preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: "Update", style: .destructive, handler: { (a) in
                    device!.peripheral.writeValue("XB".data(using: .utf8)!, for: device!.txUart!, type: .withoutResponse)
                    
                    SVProgressHUD.show(withStatus: "Device Updating...")
                }))
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (a) in
                    self.axleCentralManger?.cancelPeripheralConnection(peripheral)
                }))
                
                present(alert, animated: true)
            }
            else
            {
                axleCentralManger?.cancelPeripheralConnection(peripheral)
                
                device?.mac = String(bytes: characteristic.value!, encoding: .utf8)!
                
                tableView.reloadData()
            }
        }
    }
    
    func dfuProgressDidChange(for part: Int, outOf totalParts: Int, to progress: Int, currentSpeedBytesPerSecond: Double, avgSpeedBytesPerSecond: Double) {
        print("DFU PROGRESS -- \(progress)")
        SVProgressHUD.showProgress(Float(progress) / Float(100))
    }
    
    func dfuStateDidChange(to state: DFUState) {
        print("DFU STATE -- \(state)")
        if state == DFUState.completed
        {
            SVProgressHUD.showSuccess(withStatus: "Device successfully updated!")
        }
    }
    
    func dfuError(_ error: DFUError, didOccurWithMessage message: String) {
        print("DFU ERROR -- \(error) -- \(message)")
    }
    
    func logWith(_ level: LogLevel, message: String) {
        print("DFU LOG -- \(level) -- \(message)")
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return devices.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Device")!
        
        cell.textLabel?.text = devices[indexPath.row].peripheral.name
        cell.detailTextLabel?.text = devices[indexPath.row].mac
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let device = devices[indexPath.row]
        
        dfuQueue.append(device.peripheral.identifier)
        
        axleCentralManger?.connect(device.peripheral, options: nil)
    }
}
