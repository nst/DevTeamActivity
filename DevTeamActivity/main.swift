//
//  main.swift
//  DevTeamActivity
//
//  Created by nst on 17/02/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import Foundation
import AppKit

func extractData() {
    
    let repos = [
        "/Users/nst/Projects/swift"
    ]
    
    for path in repos {
        extractCommits(.git, repositoryPath: path, fromDay: "2011-01-01", toDay: "2016-10-31") { (path) -> () in
            print("->", path)
        }
    }
}

func draw() {
    
    let fromDay = "2011-01-01"
    let toDay = "2016-10-31"
    
    var repoTuples : [(repo:String, jsonPath:String)] = []
    
    for s in ["swift"] {
        let path = ("~/Desktop/\(s)_\(fromDay)_\(toDay).json" as NSString).expandingTildeInPath
        let t = (repo:s, jsonPath:path)
        repoTuples.append(t)
    }
    
    let outPath = ("~/Desktop/team_activity_\(fromDay)_\(toDay).png" as NSString).expandingTildeInPath
    
    try! ChartMonth().drawTimeline(fromDay:fromDay, toDay:toDay, repoTuples: repoTuples, outPath:outPath)
    
    print(outPath)
    
    NSWorkspace.shared().openFile(outPath)
    
}

//extractData()

draw()
