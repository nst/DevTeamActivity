//
//  Chart.swift
//  DevTeamActivity
//
//  Created by nst on 02/03/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import Foundation

infix operator +=? { associativity right precedence 90 }
func +=? (inout left: Int, right: Int?) {
    if let existingRight = right {
        left = left + existingRight
    }
}
