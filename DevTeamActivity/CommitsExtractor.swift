//
//  main.swift
//  hgReport
//
//  Created by Nicolas Seriot on 02/02/16.
//  Copyright © 2016 seriot.ch. All rights reserved.
//

import Foundation

struct RegularExpression {
    static func findAll(string s: String, pattern: String) throws -> [String] {
        
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(in: s, options: [], range: NSMakeRange(0, s.characters.count))
        
        var results : [String] = []
        
        for m in matches {
            for i in 1..<m.numberOfRanges {
                let range = m.rangeAt(i)
                results.append((s as NSString).substring(with: range))
            }
        }
        
        return results
    }
}

enum CommitExtractorError : Error {
    case badFormat
    case badValues
}

enum VCS {
    case git
    case mercurial
    
    func processToGetLogsForRepository(_ repositoryPath:String, fromDay:String, toDay:String) -> Process {
        
        let process = Process()
        
        switch(self) {
        case .git:
            process.launchPath = "/usr/bin/git"
            process.arguments = ["--git-dir=\(repositoryPath)/.git", "log", "--pretty=\"%aI %ae\"", "--shortstat", "--after=\(fromDay)", "--before=\(toDay)"]
        case .mercurial:
            process.launchPath = "/usr/local/bin/hg"
            process.arguments = ["log", "--template", "{date(date,'%Y-%m-%d')} {author|email} {diffstat}\\n", "--date", "\(fromDay) to \(toDay)", "--repository", repositoryPath]
        }
        
        guard let path = process.launchPath else { assertionFailure(); return process }
        guard FileManager.default.fileExists(atPath: path) else { assertionFailure(); return process }
        
        let pipe = Pipe()
        process.standardOutput = pipe
        //        task.standardError = task.standardOutput
        
        print("-- \(process.launchPath!) \(process.arguments!.joined(separator: " "))")
        
        return process
    }
    
    func dataInLogLines(_ lines: [String]) throws -> [(day:String, email:String, added:Int, removed:Int)] {
        switch(self) {
        case .git:
            return try self.dataInGitLogLines(lines)
        case .mercurial:
            return try self.dataInHgLogLines(lines)
        }
    }
    
    func dataInGitLogLines(_ lines: [String]) throws -> [(day:String, email:String, added:Int, removed:Int)] {
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
                date = s.substring(with: NSMakeRange(1, 10))
                if let emailWithEndingQuote = s.components(separatedBy: " ").last {
                    let len = emailWithEndingQuote.lengthOfBytes(using: String.Encoding.utf8)
                    email = (emailWithEndingQuote as NSString).substring(with: NSMakeRange(0, len-1))
                }
            } else {
                print(line)
                
                let insertions = try RegularExpression.findAll(string: line, pattern: "\\s(\\d+?)\\sinsertion")
                let deletions = try RegularExpression.findAll(string: line, pattern: "\\s(\\d+?)\\sdeletion")
                
                if let insertionsCount = insertions.first , insertions.count == 1 {
                    added = Int(insertionsCount)
                }
                
                if let deletionsCount = deletions.first , deletions.count == 1 {
                    removed = Int(deletionsCount)
                }
                
                //
                
                guard let
                    existingDate = date,
                    let existingEmail = email,
                    let existingAdded = added,
                    let existingRemoved = removed
                    else {
                        print("***", line)
                        throw CommitExtractorError.badValues
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
    
    func dataInHgLogLines(_ lines: [String]) throws -> [(day:String, email:String, added:Int, removed:Int)] {
        
        var results : [(day:String, email:String, added:Int, removed:Int)] = []
        
        for line in lines {
            // 2016-01-25 john.doe@aol.com 1: +0/-12
            
            if line.lengthOfBytes(using: String.Encoding.utf8) == 0 {
                continue
            }
            
            let groups = try RegularExpression.findAll(string: line, pattern: "(\\S*)\\s(\\S*)\\s\\d*:\\s\\+(\\d*).-(\\d*)")
            guard groups.count == 4 else {
                print(groups)
                throw CommitExtractorError.badFormat
            }
            
            guard let
                existingAdded = Int(groups[2]),
                let existingRemoved = Int(groups[3])
                else {
                    throw CommitExtractorError.badValues
            }
            
            let t = (day:groups[0], email:groups[1], added:existingAdded, removed:existingRemoved)
            results.append(t)
        }
        
        return results
    }
    
}

typealias AddedRemoved = [String:Int]
typealias AddedRemovedForAuthor = [String:AddedRemoved]
typealias AddedRemovedForAuthorForDate = [String:AddedRemovedForAuthor]

func readLogs(_ vcs:VCS, repositoryPath:String, fromDay:String, toDay:String, completionHandler:(AddedRemovedForAuthorForDate)->()) {
    
    var results : AddedRemovedForAuthorForDate = [:]
    
    /*
    hg log --template "{date(date, '%Y-%m-%d')} {author|email} {diffstat}\n"
    2016-02-08 a.a@a.com 4: +45/-9
    2016-02-08 b.b@b.com 8: +102/-17
    2016-02-08 b.b@b.com 5: +47/-11
    
    hg log --template "{date(date, '%Y-%m-%d')} {author|email} {diffstat}\n" --date "2016-01-01 to 2016-01-31"
    */
    
    let process = vcs.processToGetLogsForRepository(repositoryPath, fromDay:fromDay, toDay:toDay)
    
    let pipe = Pipe()
    process.standardOutput = pipe
    
    process.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    
    let s = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
    guard let lines = s?.components(separatedBy: "\n") else {
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

func saveLogs(_ entries:AddedRemovedForAuthorForDate, path:String) throws -> Bool {
    let jsonData = try JSONSerialization.data(withJSONObject: entries, options: .prettyPrinted)
    return ((try? jsonData.write(to: URL(fileURLWithPath: path), options: [.atomic])) != nil)
}

func extractCommits(_ vcs:VCS, repositoryPath:String, fromDay:String, toDay:String, completionHandler:(_ path:String) -> ()) {
    
    readLogs(vcs, repositoryPath: repositoryPath, fromDay:fromDay, toDay:toDay) { (entries) -> () in
        
        print(entries)
        
        let repoName = (repositoryPath as NSString).lastPathComponent
        let path = "/Users/nst/Desktop/\(repoName)_\(fromDay)_\(toDay).json"
        
        do {
            _ = try saveLogs(entries, path:path)
            print("-- saved \(entries.count) in", path)
            completionHandler(path)
        } catch {
            print(error)
        }
        
    }
}
