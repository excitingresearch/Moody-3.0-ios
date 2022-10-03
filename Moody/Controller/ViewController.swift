//
//  ViewController.swift
//  Moody
//
//  Created by Nassim Versbraegen on 19/08/2022.
//

import UIKit
import CoreBluetooth
import CoreMotion
import CoreLocation


let locationManager = CLLocationManager()
let manager = CMMotionManager()
let userDefaults = UserDefaults.standard
let NAME_KEY = "moodyname"
let server = "http://134.122.18.168:2000/"

func store(name : String){
    userDefaults.set(name, forKey: NAME_KEY)
}

class ViewController: UIViewController {

    // Data
    private var centralManager: CBCentralManager!
    private var moodyPeripheral: CBPeripheral!
    private var txCharacteristic: CBCharacteristic!
    private var rxCharacteristic: CBCharacteristic!
    private var peripheralArray: [CBPeripheral] = []
    private var rssiArray = [NSNumber]()
    private var timer = Timer()
    private var moodyID: String! = userDefaults.object(forKey: NAME_KEY) as? String
    private var gyro: [Double] = [0,0,0]

    // UI
//    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var peripheralFoundLabel: UILabel!
    @IBOutlet weak var scanningLabel: UILabel!
    @IBOutlet weak var scanningButton: UIButton!
    @IBOutlet weak var backgroundGradientView: UIView!
    @IBOutlet weak var enteredMoodyID: UITextField!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var disconnectButton: UIButton!
    @IBOutlet weak var rawvalue: UILabel!
    @IBOutlet weak var color: UIButton!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var sliderlabel: UILabel!
    @IBOutlet weak var savinglabel: UILabel!
    @IBOutlet weak var  power: UISwitch!
    

    @IBAction func scanningAction(_ sender: Any) {
    startScanning()
  }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Manager
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        //background
        // Create a gradient layer.
        generateBackground()
        
        if moodyID != nil {
            enteredMoodyID.text = moodyID
        }
        
        //motino
        manager.gyroUpdateInterval = 1
        manager.startDeviceMotionUpdates(to: .main) { (motion, error) in
            if (motion != nil){
                let rate = motion!.rotationRate
                self.gyro = [rate.x,rate.y, rate.z]
            }
        }
        
        //location
        locationManager.requestAlwaysAuthorization()
        
        //ui
        disconnectButton.isHidden = true;
        color.isHidden = true;
        slider.isHidden = true;
        sliderlabel.isHidden = true;
        savinglabel.isHidden = true;
        power.isHidden = true;
    }
    
    func alert(message: String){
        let alertVC = UIAlertController(title: "Alert", message: message, preferredStyle: UIAlertController.Style.alert)

        let action = UIAlertAction(title: "Ok", style: UIAlertAction.Style.default, handler: { (action: UIAlertAction) -> Void in
            self.dismiss(animated: true, completion: nil)
        })

        alertVC.addAction(action)

        self.present(alertVC, animated: true, completion: nil)
    }
    
    func generateBackground(){
        let gradientLayer = CAGradientLayer()
        
        gradientLayer.frame = {()->CGRect in
            let b = view.bounds;
            let w = b.width;
            return CGRectMake(b.origin.x-w/2, b.origin.y, w*2, b.height)}()
        
        gradientLayer.type = .radial
        gradientLayer.colors = [ UIColor.red.cgColor,
            UIColor.yellow.cgColor,
            UIColor.green.cgColor,
            UIColor.blue.cgColor]
        gradientLayer.locations = [ 0, 0.3, 0.7, 1 ]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        // Rasterize this static layer to improve app performance.
        gradientLayer.shouldRasterize = true
        backgroundGradientView.layer.insertSublayer(gradientLayer, at: 0)
    }
    
    @IBAction func connectButtonPressed(_ sender: UIButton, forEvent event: UIEvent){
        
        var connected = false
        
        if (enteredMoodyID.hasText){
            // see if we can connect to Moody
            
            for m in peripheralArray{
                print(m)
                if (m.name != nil && m.name! == enteredMoodyID.text!){
                    store(name: enteredMoodyID.text!)
                    moodyPeripheral = m;
                    connectToDevice()
                    toggleConnectionUI();
                    connectToDevice()
                    connected = true;
                    self.view.endEditing(true)
                }
            }
        }
        if(!connected){
            alert(message: "connection error")
        }
    }
    
    @IBAction func brightlider(sender: UISlider){
        let n = Int(sender.value * 100)
        let st = String(format:"%02X", n)
        writeOutgoingValue(data: "3"+st)
    }
    
    @IBAction func powersaving(sender: UISwitch){
        
        let st = String(format:"%02X", sender.isOn ? 1000:3000)
        writeOutgoingValue(data: "2"+st)
    }
    
    @IBAction func disconnectButtonPressed(_ sender: UIButton, forEvent event: UIEvent){
        disconnectFromDevice()
        toggleConnectionUI()
    }
    
    func valueReceived(temperature : Int?, r: Float?, g: Float?, b: Float?){
        if let temperature = temperature, let r = r, let g = g,let b = b {
            if(color.isHidden){
                color.isHidden = false
            }
            
            rawvalue.text = String(Float(temperature)/100.0)
            
            let col = [Double(r/255.0), Double(g/255.0), Double(b/255.0)]
            var location: [Double] = []
            
            color.tintColor = UIColor(        red:      CGFloat(col[0]),
                                              green:    CGFloat(col[1]),
                                              blue:     CGFloat(col[2]),
                                              alpha: 0.5)
            
            
            var surround : [(String, Double)] = [];
            
            for (index, peripheral) in peripheralArray.enumerated() {
                let name:String = peripheral.name!;
                let pname:String = moodyPeripheral.name!
                if (name != pname){
                    let v = Double(exactly: rssiArray[index])!
                    surround.append((key:name, value:v))
                }
            }

            if (locationManager.location != nil){
                let coordinate = locationManager.location!.coordinate
                location = [coordinate.longitude, coordinate.latitude]
            }
            sendDataToServer(temperature: Double(temperature)/100, color: col, location: location, gyro: gyro, proximity: surround)
        }
    }
    
    func sendDataToServer(temperature: Double, color: [Double], location: [Double], gyro: [Double], proximity: [(String, Double)]){
        var urlComponents = URLComponents(string: server+"addData")!
        
        var s = "\"["
        for p in proximity {
            s = s + "{'id':'"+p.0 + "','distance':" + String(abs(p.1)) + "},";
        }
        s+="]\""

        urlComponents.queryItems = [
            URLQueryItem(name: "moodid", value: String(moodyPeripheral.name!)),
            URLQueryItem(name: "temperature", value: String(temperature)),
            URLQueryItem(name: "color", value: color.description),
            URLQueryItem(name: "excitement", value: temperature.description),
            URLQueryItem(name: "location", value: location.description),
            URLQueryItem(name: "gyro", value: gyro.description),
            URLQueryItem(name: "proximity", value: s),
        ]
        
        let task = URLSession.shared.dataTask(with: urlComponents.url!) { data, response, error in
                guard
                    error == nil,
                    let data = data,
                    let string = String(data: data, encoding: .utf8)
                else {
                    print(error ?? "Unknown error")
                    return
                }

                print(string)
            }
            task.resume()
    }

    override func viewDidAppear(_ animated: Bool) {
      disconnectFromDevice()
    }
    
    func writeOutgoingValue(data: String){
        let valueString = (data as NSString).data(using: String.Encoding.utf8.rawValue)
        moodyPeripheral.writeValue(valueString!, for: txCharacteristic!, type: CBCharacteristicWriteType.withResponse)
    }
    
    func toggleConnectionUI()-> Void {
        enteredMoodyID.isHidden = !enteredMoodyID.isHidden;
        connectButton.isHidden = !connectButton.isHidden;
        disconnectButton.isHidden = !disconnectButton.isHidden;
        slider.isHidden = !slider.isHidden;
        sliderlabel.isHidden = !sliderlabel.isHidden;
        power.isHidden = !power.isHidden;
        savinglabel.isHidden = !savinglabel.isHidden;
    }
    
    func connectToDevice() -> Void {
      centralManager?.connect(moodyPeripheral!, options: nil)
  }

    func disconnectFromDevice() -> Void {
      if moodyPeripheral != nil {
        centralManager?.cancelPeripheralConnection(moodyPeripheral!)
      }
    }

    func removeArrayData() -> Void {
      centralManager.cancelPeripheralConnection(moodyPeripheral)
           rssiArray.removeAll()
           peripheralArray.removeAll()
       }

    func startScanning() -> Void {
//        print("starting scann")
        // Remove prior data
        peripheralArray.removeAll()
        rssiArray.removeAll()
        // Start Scanning
        centralManager?.scanForPeripherals(withServices: [CBUUIDs.BLEService_UUID])
        scanningLabel.text = "Scanning..."
        scanningButton.isEnabled = false
        
        var wait = 15.0
        if (moodyPeripheral != nil){
            wait = 5.0
        }
        
        Timer.scheduledTimer(withTimeInterval: wait, repeats: false) {_ in
            self.stopScanning()
        }
    }

//    func scanForBLEDevices() -> Void {
//      // Remove prior data
//      peripheralArray.removeAll()
//      rssiArray.removeAll()
//      // Start Scanning
//      centralManager?.scanForPeripherals(withServices: [] , options: [CBCentralManagerScanOptionAllowDuplicatesKey:true])
//      scanningLabel.text = "Scanning..."
//
//      Timer.scheduledTimer(withTimeInterval: 15, repeats: false) {_ in
//          self.stopScanning()
//      }
//  }

    func stopTimer() -> Void {
      // Stops Timer
      self.timer.invalidate()
    }

    func stopScanning() -> Void {
        scanningLabel.text = ""
        scanningButton.isEnabled = true
        centralManager?.stopScan()
//        print("stop scanning")
        Timer.scheduledTimer(withTimeInterval: 1, repeats: false) {_ in
            self.startScanning()
        }
    }

    func delayedConnection() -> Void {
        BlePeripheral.connectedPeripheral = moodyPeripheral
  }
}

// MARK: - CBCentralManagerDelegate
// A protocol that provides updates for the discovery and management of peripheral devices.
extension ViewController: CBCentralManagerDelegate {

    // MARK: - Check
    func centralManagerDidUpdateState(_ central: CBCentralManager) {

      switch central.state {
        case .poweredOff:
            print("Is Powered Off.")

            let alertVC = UIAlertController(title: "Bluetooth Required", message: "Check your Bluetooth Settings", preferredStyle: UIAlertController.Style.alert)

            let action = UIAlertAction(title: "Ok", style: UIAlertAction.Style.default, handler: { (action: UIAlertAction) -> Void in
                self.dismiss(animated: true, completion: nil)
            })

            alertVC.addAction(action)

            self.present(alertVC, animated: true, completion: nil)

        case .poweredOn:
            print("Is Powered On.")
            startScanning()
        case .unsupported:
            print("Is Unsupported.")
        case .unauthorized:
        print("Is Unauthorized.")
        case .unknown:
            print("Unknown")
        case .resetting:
            print("Resetting")
        @unknown default:
          print("Error")
        }
    }

    // MARK: - Discover
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
//      print("Function: \(#function),Line: \(#line)")
        if (moodyPeripheral == nil){
            moodyPeripheral = peripheral
        }
      
      if peripheralArray.contains(peripheral) {
          print("Duplicate Found.")
      } else {
        peripheralArray.append(peripheral)
        rssiArray.append(RSSI)
      }
      peripheralFoundLabel.text = "Peripherals Found: \(peripheralArray.count)"
        if (peripheral.name! == moodyPeripheral.name!){
            moodyPeripheral.delegate = self
        }
      
        if peripheral.name != nil && peripheral.name!.contains("moody") {
//            print("Peripheral Discovered: \(peripheral)")
//            print("Peripheral Name: \(peripheral.name ?? "No Name")")
//            print("Peripheral Strength: \(RSSI)")
        }
    }
    
    // MARK: - Connect
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        stopScanning()
        moodyPeripheral.discoverServices([CBUUIDs.BLEService_UUID])
    }
}

// MARK: - CBPeripheralDelegate
// A protocol that provides updates on the use of a peripheral’s services.
extension ViewController: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
      guard let services = peripheral.services else { return }
      for service in services {
        peripheral.discoverCharacteristics(nil, for: service)
      }
      BlePeripheral.connectedService = services[0]
    }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    guard let characteristics = service.characteristics else {
        return
    }
    print("Found \(characteristics.count) characteristics.")
    for characteristic in characteristics {
      if characteristic.uuid.isEqual(CBUUIDs.BLE_Characteristic_uuid_Rx)  {
        rxCharacteristic = characteristic
        BlePeripheral.connectedRXChar = rxCharacteristic
        peripheral.setNotifyValue(true, for: rxCharacteristic!)
        peripheral.readValue(for: characteristic)
        print("RX Characteristic: \(rxCharacteristic.uuid)")
      }

      if characteristic.uuid.isEqual(CBUUIDs.BLE_Characteristic_uuid_Tx){
        txCharacteristic = characteristic
        BlePeripheral.connectedTXChar = txCharacteristic
        print("TX Characteristic: \(txCharacteristic.uuid)")
      }
    }
    delayedConnection()
 }

  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    var characteristicASCIIValue = NSString()
    guard characteristic == rxCharacteristic,
          let characteristicValue = characteristic.value,
          let ASCIIstring = NSString(data: characteristicValue, encoding: String.Encoding.utf8.rawValue) else { return }
      characteristicASCIIValue = ASCIIstring
//      print("Value Recieved: \((characteristicASCIIValue as String))")
      
    let vals = (characteristicASCIIValue as String).replacingOccurrences(of: ")", with:"").replacingOccurrences(of: "(", with: "").replacingOccurrences(of: " ", with: "").components(separatedBy: CharacterSet(charactersIn: ",|"))
      
      if (vals.count == 4){
          valueReceived(temperature: Int(vals[0]), r: Float(vals[1]), g: Float(vals[2]), b: Float(vals[3]))
      }
    NotificationCenter.default.post(name:NSNotification.Name(rawValue: "Notify"), object: "\((characteristicASCIIValue as String))")
  }

  func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        peripheral.readRSSI()
  }

  func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
      guard error == nil else {
          print("Error discovering services: error")
          return
      }
    print("Function: \(#function),Line: \(#line)")
      print("Message sent")
  }


  func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
      print("*******************************************************")
    print("Function: \(#function),Line: \(#line)")
      if (error != nil) {
          print("Error changing notification state:\(String(describing: error?.localizedDescription))")
      } else {
          print("Characteristic's value subscribed")
      }
      if (characteristic.isNotifying) {
          print ("Subscribed. Notification has begun for: \(characteristic.uuid)")
      }
  }
}

//// MARK: - UITableViewDataSource
//// The methods adopted by the object you use to manage data and provide cells for a table view.
//extension ViewController: UITableViewDataSource {
//
//    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        return self.peripheralArray.count
//    }
//
//
//    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//
//      let cell = tableView.dequeueReusableCell(withIdentifier: "BlueCell") as! TableViewCell
//
//      let peripheralFound = self.peripheralArray[indexPath.row]
//
//      let rssiFound = self.rssiArray[indexPath.row]
//
//        if peripheralFound.name == nil {
//            cell.peripheralLabel.text = "Unknown"
//        }else {
//            cell.peripheralLabel.text = peripheralFound.name
//            cell.rssiLabel.text = "RSSI: \(rssiFound)"
//        }
//        return cell
//    }
//
//
//}
//
//
//// MARK: - UITableViewDelegate
//// Methods for managing selections, deleting and reordering cells and performing other actions in a table view.
//extension ViewController: UITableViewDelegate {
//
//    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//
//      moodyPeripheral = peripheralArray[indexPath.row]
//
//        BlePeripheral.connectedPeripheral = moodyPeripheral
//
//        connectToDevice()
//
//    }
//}
//
