//
//  Array+Subscript.swift
//  VVMediaLibrary
//
//  Created by Volodymyr Vrublevskyi on 4/23/19.
//  Copyright © 2019 NerdzLab. All rights reserved.
//

import Foundation

extension Array {
    public subscript(safeIndex index: Int) -> Element? {
        guard index >= 0, index < endIndex else {
            return nil
        }
        
        return self[index]
    }
}
