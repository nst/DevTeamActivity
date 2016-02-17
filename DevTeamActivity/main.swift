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
        "/Users/nst/Projects/repo1",
        "/Users/nst/Projects/repo2",
        "/Users/nst/Projects/repo3"
    ]
    
    for path in repos {
        extractCommits(.Mercurial, repositoryPath: path, fromDay: "2016-01-01", toDay: "2016-02-15") { (path) -> () in
            print("->", path)
        }
    }
    
    //    CFRunLoopRun()
}

func draw() {
    
    let fromDay = "2016-01-01"
    let toDay = "2016-02-15"
    
    var repoTuples : [(repo:String, jsonPath:String)] = []
    
    for s in ["repo1", "repo2", "repo3"] {
        let path = ("~/Desktop/\(s)_\(fromDay)_\(toDay).json" as NSString).stringByExpandingTildeInPath
        let t = (repo:s, jsonPath:path)
        repoTuples.append(t)
    }
    
    let outPath = ("~/Desktop/team_activity_\(fromDay)_\(toDay).png" as NSString).stringByExpandingTildeInPath
    
    try! Chart().drawTimeline(fromDay:fromDay, toDay:toDay, repoTuples: repoTuples, outPath:outPath)
    
    print(outPath)
    
    NSWorkspace.sharedWorkspace().openFile(outPath)
    
}

extractData()

draw()
