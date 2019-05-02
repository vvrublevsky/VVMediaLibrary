//
//  Int + String.swift
//  VVMediaLibrary
//
//  Created by Volodymyr Vrublevskyi on 4/26/19.
//  Copyright © 2019 NerdzLab. All rights reserved.
//

import Foundation

extension Int {
    func toMinutesString() -> String {
        let minutes = self / 60
        let seconds = self % 60
        
        let minutesString = minutes < 10 ? "0\(minutes)" : "\(minutes)"
        let secondsString = seconds < 10 ? "0\(seconds)" : "\(seconds)"
        
        return "\(minutesString):\(secondsString)"
    }
}
