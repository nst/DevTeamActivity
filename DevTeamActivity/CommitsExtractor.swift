//
//  main.swift
//  hgReport
//
//  Created by Nicolas Seriot on 02/02/16.
//  Copyright © 2016 seriot.ch. All rights reserved.
//

import Foundation

enum Error : ErrorType {
    case BadFormat
    case BadValues
}

enum VCS {
    case Git
    case Mercurial
    
    func taskToGetLogsForRepository(repositoryPath:String, fromDay:String, toDay:String) -> NSTask {
        
        let task = NSTask()
        
        switch(self) {
        case .Git:
            task.launchPath = "/usr/bin/git"
            task.arguments = ["--git-dir=\(repositoryPath)/.git", "log", "--pretty=\"%aI %ae\"", "--shortstat", "--after=\(fromDay)", "--before=\(toDay)"]
        case .Mercurial:
            task.launchPath = "/usr/local/bin/hg"
            task.arguments = ["log", "--template", "{date(date,'%Y-%m-%d')} {author|email} {diffstat}\\n", "--date", "\(fromDay) to \(toDay)", "--repository", repositoryPath]
        }
        
        guard let path = task.launchPath else { assertionFailure(); return task }
        guard NSFileManager.defaultManager().fileExistsAtPath(path) else { assertionFailure(); return task }
        
        let pipe = NSPipe()
        task.standardOutput = pipe
        //        task.standardError = task.standardOutput
        
        print("-- \(task.launchPath!) \(task.arguments!.joinWithSeparator(" "))")
        
        return task
    }
    
    func dataInLogLines(lines: [String]) throws -> [(day:String, email:String, added:Int, removed:Int)] {
        switch(self) {
        case .Git:
            return try self.dataInGitLogLines(lines)
        case .Mercurial:
            return try self.dataInHgLogLines(lines)
        }
    }
    
    func dataInGitLogLines(lines: [String]) throws -> [(day:String, email:String, added:Int, removed:Int)] {
        /*
        "2015-12-25T15:50:00+01:00 nicolas@seriot.ch"
        
        2 files changed, 3 insertions(+), 4 deletions(-)
        2 files changed, 4 deletions(-)
        */
        
        var results = [(day:String, email:String, added:Int, removed:Int)]()
        
        var date : String? = nil
        var email : String? = nil
        var added : Int? = 0
        var removed : Int? = 0
        
        for line in lines {
            let s = (line as NSString)
            
            if s.length == 0 {
                continue
            }
            
            if s.hasPrefix(" ") == false {
                date = s.substringWithRange(NSMakeRange(1, 10))
                if let emailWithEndingQuote = s.componentsSeparatedByString(" ").last {
                    let len = emailWithEndingQuote.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
                    email = (emailWithEndingQuote as NSString).substringWithRange(NSMakeRange(0, len-1))
                }
            } else {
                print(line)
                
                let insertions = try matches(string: line, pattern: "\\s(\\d+?)\\sinsertion")
                let deletions = try matches(string: line, pattern: "\\s(\\d+?)\\sdeletion")
                
                if let insertionsCount = insertions.first where insertions.count == 1 {
                    added = Int(insertionsCount)
                }
                
                if let deletionsCount = deletions.first where deletions.count == 1 {
                    removed = Int(deletionsCount)
                }
                
                //
                
                guard let
                    existingDate = date,
                    existingEmail = email,
                    existingAdded = added,
                    existingRemoved = removed
                    else {
                        print("***", line)
                        throw Error.BadValues
                }
                
                let t = (day:existingDate, email:existingEmail, added:existingAdded, removed:existingRemoved)
                results.append(t)
                
                email = nil
                date = nil
                added = 0
                removed = 0
            }
        }
        
        return results
    }
    
    func dataInHgLogLines(lines: [String]) throws -> [(day:String, email:String, added:Int, removed:Int)] {
        
        var results : [(day:String, email:String, added:Int, removed:Int)] = []
        
        for line in lines {
            // 2016-01-25 john.doe@aol.com 1: +0/-12
            
            if line.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) == 0 {
                continue
            }
            
            let groups = try matches(string: line, pattern: "(\\S*)\\s(\\S*)\\s\\d*:\\s\\+(\\d*).-(\\d*)")
            guard groups.count == 4 else {
                print(groups)
                throw Error.BadFormat
            }
            
            guard let
                existingAdded = Int(groups[2]),
                existingRemoved = Int(groups[3])
                else {
                    throw Error.BadValues
            }
            
            let t = (day:groups[0], email:groups[1], added:existingAdded, removed:existingRemoved)
            results.append(t)
        }
        
        return results
    }
    
}

func matches(string s: String, pattern: String) throws -> [String] {
    
    let regex = try NSRegularExpression(pattern: pattern, options: [])
    let matches = regex.matchesInString(s, options: [], range: NSMakeRange(0, s.characters.count))
    
    guard matches.count > 0 else { return [] }
    
    let textCheckingResult = matches[0]
    
    var results = [String]()
    
    for index in 1..<textCheckingResult.numberOfRanges {
        results.append((s as NSString).substringWithRange(textCheckingResult.rangeAtIndex(index)))
    }
    
    return results
}

typealias AddedRemoved = [String:Int]
typealias AddedRemovedForAuthor = [String:AddedRemoved]
typealias AddedRemovedForAuthorForDate = [String:AddedRemovedForAuthor]

func readLogs(vcs:VCS, repositoryPath:String, fromDay:String, toDay:String, completionHandler:(AddedRemovedForAuthorForDate)->()) {
    
    var results : AddedRemovedForAuthorForDate = [:]
    
    /*
    hg log --template "{date(date, '%Y-%m-%d')} {author|email} {diffstat}\n"
    2016-02-08 a.a@a.com 4: +45/-9
    2016-02-08 b.b@b.com 8: +102/-17
    2016-02-08 b.b@b.com 5: +47/-11
    
    hg log --template "{date(date, '%Y-%m-%d')} {author|email} {diffstat}\n" --date "2016-01-01 to 2016-01-31"
    */
    
    let task = vcs.taskToGetLogsForRepository(repositoryPath, fromDay:fromDay, toDay:toDay)
    
    guard let fileHandle = task.standardOutput?.fileHandleForReading else {
        print("no file handle")
        completionHandler([:])
        return
    }
    
    task.launch()
    
    let data = fileHandle.readDataToEndOfFile()
    let s = NSString(data: data, encoding: NSUTF8StringEncoding)
    guard let lines = s?.componentsSeparatedByString("\n") else {
        completionHandler([:])
        return
    }
    
    do {
        let entries = try vcs.dataInLogLines(lines)
        
        print(entries)
        
        for e in entries {
            let (day, author, added, removed) = e
            print(e)
            
            if results[day] == nil {
                results[day] = [:]
            }
            
            if results[day]?[author] == nil {
                results[day]?[author] = [:]
            }
            
            if results[day]?[author]?["added"] == nil {
                results[day]?[author]?["added"] = 0
            }
            
            if results[day]?[author]?["removed"] == nil {
                results[day]?[author]?["removed"] = 0
            }
            
            results[day]?[author]?["added"]? += added
            results[day]?[author]?["removed"]? += removed
        }
        
    } catch {
        print("*** ERROR:", error)
    }
    
    completionHandler(results)
}

func saveLogs(entries:AddedRemovedForAuthorForDate, path:String) throws -> Bool {
    let jsonData = try NSJSONSerialization.dataWithJSONObject(entries, options: .PrettyPrinted)
    return jsonData.writeToFile(path, atomically: true)
}

func extractCommits(vcs:VCS, repositoryPath:String, fromDay:String, toDay:String, completionHandler:(path:String) -> ()) {
    
    readLogs(vcs, repositoryPath: repositoryPath, fromDay:fromDay, toDay:toDay) { (entries) -> () in
        
        print(entries)
        
        let repoName = (repositoryPath as NSString).lastPathComponent
        let path = "/Users/nst/Desktop/\(repoName)_\(fromDay)_\(toDay).json"
        
        do {
            try saveLogs(entries, path:path)
            print("-- saved \(entries.count) in", path)
            completionHandler(path: path)
        } catch {
            print(error)
        }
        
    }
}
