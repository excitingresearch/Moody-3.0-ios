//
//  BlePeripheral.swift
//  Moody
//
//  Created by Nassim Versbraegen on 19/08/2022.
//

import Foundation

import CoreBluetooth

class BlePeripheral {
 static var connectedPeripheral: CBPeripheral?
 static var connectedService: CBService?
 static var connectedTXChar: CBCharacteristic?
 static var connectedRXChar: CBCharacteristic?
}
