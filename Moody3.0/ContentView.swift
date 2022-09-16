//
//  ContentView.swift
//  Moody3.0
//
//  Created by Pieter Steyaert on 16/08/2022.
//

import SwiftUI
import Foundation

let userDefaults = UserDefaults.standard
let NAME_KEY = "moodyname"


func connectMoody(name : String) {
    print("connecting :: " + name)
}

func store(name : String){
    userDefaults.set(name, forKey: NAME_KEY)
}

class GlowBall: UIView {
    private lazy var pulse: CAGradientLayer = {
        let l = CAGradientLayer()
        l.type = .radial
        l.colors = [ UIColor.red.cgColor,
            UIColor.yellow.cgColor,
            UIColor.green.cgColor,
            UIColor.blue.cgColor]
        l.locations = [ 0, 0.3, 0.7, 1 ]
        l.startPoint = CGPoint(x: 0.5, y: 0.5)
        l.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(l)
        return l
    }()

    override func layoutSubviews() {
        super.layoutSubviews()
        pulse.frame = bounds
        pulse.cornerRadius = bounds.width / 2.0
    }
}
    

struct ContentView: View {
//    @State private var speed = 50.0
//    @State private var isEditing = false
    @State private var connected = false
    @State private var identifier = userDefaults.object(forKey: NAME_KEY) as? String
    
    
    @State private var newname: String = ""
    @State private var emailFieldIsFocused = false
    @State private var showingAlert = false
    
    @State private var signalStrength = "😃"
    
    
    
    var body: some View {
        
        let gradientWithFourColors = Gradient(colors: [
            Color.blue,
            Color.pink,
            Color.yellow,
            Color.green
            ]
        )
        
        VStack() {
            HStack {
               Spacer()
             }
            Text("MOODY")
                .foregroundColor(.white)
                .font(.largeTitle)
            
            if (identifier == nil){
                TextField(
                        "Enter moody name",
                        text: $newname
                    )
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .border(.secondary)
                    .padding(20.0)

                    Button("Submit") {
                            print("submitting :: " + newname)
                            
                        // connect with moody here
                        identifier = newname
                        connectMoody(name: identifier!)
                        
                        //only store in defaults when the connection was succesfull
                        store(name: newname)
                        
                    }.padding().border(.secondary).padding(10).foregroundColor(.white)
                        
            } else {
                Text("Device :: " + identifier!)
                    .foregroundColor(.white).padding()
                
                Text("Signal Strength :: " + signalStrength)
                    .foregroundColor(.white).padding()
                
                Button("Reset") {
                    identifier = nil
                    newname = ""
                }.padding().border(.secondary).padding(10).foregroundColor(.white)
                
                Spacer()
                Spacer()
                Spacer()
                Spacer()
                Spacer()
                Spacer()
                Text("[Exciting Research](https://excitingresearch.io)")
                    .foregroundColor(.white)
                    
                    
                
            }
            
            Spacer()
            
        }
        .onAppear {
            if (identifier != nil){
                connectMoody(name: identifier!)
            }
        }
        .background(RadialGradient(gradient: gradientWithFourColors, center: .center, startRadius: 0, endRadius: 520))
    }
      

}

//struct ContentView: View {
//    @State private var speed = 50.0
//    @State private var isEditing = false
//
//    var body: some View {
//        VStack(alignment: .leading) {
//            HStack {
//               Spacer()
//             }
//            Slider(
//                value: $speed,
//                in: 0...100,
//                onEditingChanged: { editing in
//                    isEditing = editing
//                }
//            )
//            Text("\(speed)")
//                .foregroundColor(isEditing ? .orange : .yellow)
//            Spacer()
//        }
//        .background(Color.purple)
//    }
//
//}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


//mySlider = UISlider(frame:CGRect(x: 0, y: 0, width: 300, height: 20))
//mySlider.center = self.view.center
