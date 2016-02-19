//
//  ChartWeek.swift
//  hgReport
//
//  Created by Nicolas Seriot on 09/02/16.
//  Copyright © 2016 seriot.ch. All rights reserved.
//

import Cocoa

struct Chart {
    
    struct Constants {
        static let COL_WIDTH = 20
        static let ROW_HEIGHT = 20
        static let LEFT_MARGIN_WIDTH = 20
        static let TOP_MARGIN_HEIGTH = 100
    }
    
    var dateFormatter: NSDateFormatter = {
        let df = NSDateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = NSTimeZone(name:"GMT")
        return df
    }()
    
    func daysInfoFromDay(fromDay:String, toDay:String) -> [String:(weekDay:Int, offset:Int)] {
        
        let calendar = NSCalendar.currentCalendar()
        
        var daysInfo : [String:(weekDay:Int, offset:Int)] = [:]
        
        let matchingComponents = NSDateComponents()
        matchingComponents.hour = 0
        
        guard let fromDate = self.dateFormatter.dateFromString(fromDay) else { assertionFailure(); return [:] }
        guard let toDate = self.dateFormatter.dateFromString(toDay) else { assertionFailure(); return [:] }
        
        var offset = 0
        
        calendar.enumerateDatesStartingAfterDate(fromDate, matchingComponents: matchingComponents, options: .MatchStrictly) { (date: NSDate?, exactMatch: Bool, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
            
            guard let existingDate = date else { assertionFailure(); return }
            
            let day = self.dateFormatter.stringFromDate(existingDate)
            
            let weekDay = calendar.component(.Weekday, fromDate:existingDate)
            
            daysInfo[day] = (weekDay, offset)
            
            let isDayOff = (weekDay == 1 || weekDay == 2)
            offset += isDayOff ? 2 : Constants.COL_WIDTH
            
            if existingDate.compare(toDate) != NSComparisonResult.OrderedAscending {
                stop.memory = true
            }
        }
        
        return daysInfo
    }
    
    func rectForDay(offset:Int, rowIndex:Int, canvasHeight:Int) -> Rect? {
        
        let COL_WIDTH = Constants.COL_WIDTH
        let ROW_HEIGHT = Constants.ROW_HEIGHT
        let LEFT_MARGIN_WIDTH = Constants.LEFT_MARGIN_WIDTH
        let TOP_MARGIN_HEIGTH = Constants.TOP_MARGIN_HEIGTH
        
        let p = P(
            LEFT_MARGIN_WIDTH + offset,
            canvasHeight - TOP_MARGIN_HEIGTH - (rowIndex+1) * ROW_HEIGHT
        )
        
        return Rect(p, width:COL_WIDTH, height:ROW_HEIGHT)
    }
    
    func fillColorForLineCountPerDay(count:Int, baseColor:NSColor) -> NSColor {
        var intensity : CGFloat
        
        switch(count) {
        case count where count > 5000:
            intensity = 1.0
        case count where count > 4000:
            intensity = 0.8
        case count where count > 2500:
            intensity = 0.6
        case count where count > 1000:
            intensity = 0.4
        case count where count > 0:
            intensity = 0.2
        default:
            intensity = 0.0
        }
        
        return baseColor.colorWithAlphaComponent(intensity)
    }
    
    static var colorPalette = [
        NSColor.blueColor(),
        NSColor.greenColor(),
        NSColor.redColor(),
        NSColor.yellowColor(),
        NSColor.cyanColor(),
        NSColor.purpleColor(),
        NSColor.orangeColor(),
        NSColor.magentaColor()
    ]
    
    static var colorForAuthors : [String:NSColor] = [:]
    
    func colorForAuthor(author:String) -> NSColor {
        
        if Chart.colorForAuthors[author] == nil {
            if let color = Chart.colorPalette.popLast() {
                Chart.colorForAuthors[author] = color
            } else {
                Chart.colorForAuthors[author] = NSColor.darkGrayColor()
            }
        }
        
        if let color = Chart.colorForAuthors[author] {
            return color
        } else {
            assertionFailure()
            return NSColor.whiteColor()
        }
    }
    
    func drawTimeline(fromDay fromDay:String, toDay:String, repoTuples:[(repo:String, jsonPath:String)], outPath:String) throws {
        
        guard let c = Canvas(880,560, backgroundColor: NSColor.whiteColor()) else {
            assertionFailure()
            return
        }
        
        let ROW_HEIGHT = Constants.ROW_HEIGHT
        let LEFT_MARGIN_WIDTH = Constants.LEFT_MARGIN_WIDTH
        
        let daysInfo = daysInfoFromDay(fromDay, toDay:toDay)
        
        let sortedDayInfo = daysInfo.sort {
            return $0.0 < $1.0
        }
        
        // draw days
        for (day, v) in daysInfo {
            let (weekDay, offset) = v
            if (weekDay == 1 || weekDay == 2) { continue }
            let p = P(LEFT_MARGIN_WIDTH + offset, c.height() - Constants.TOP_MARGIN_HEIGTH)
            c.drawText("\(day)", origin: P(p.x-13, p.y+35), fontName: "Monaco", fontSize: 10, rotationAngle: CGFloat(M_PI/2.0))
        }
        
        // draw legend
        if let (_, weekday_offset) = sortedDayInfo.last {
            let (_, offset) = weekday_offset
            let x = LEFT_MARGIN_WIDTH + offset + Constants.COL_WIDTH + 18
            
            // draw title
            c.drawText("Number of Lines Changed", origin: P(x + 10, c.height() - 25), fontName: "Monaco", fontSize: 10)
            
            let numberOfLines = ["0", "0+", "1000+", "2500+", "4000+", "5000+"]
            
            for i in 0...5 {
                let origin = P(x + 10 + i/3 * 80, c.height() - 15 - Constants.COL_WIDTH - (i%3+1) * Constants.ROW_HEIGHT)
                let r = Rect(origin, width: Constants.COL_WIDTH, height: Constants.ROW_HEIGHT)
                let intensity = CGFloat(i) * 0.2
                let color = NSColor.grayColor().colorWithAlphaComponent(intensity)
                
                c.drawRectangle(r, strokeColor: NSColor.lightGrayColor(), fillColor: color)
                
                let textPoint = P(origin.x + Constants.COL_WIDTH + 10, origin.y + 4)
                let s = numberOfLines[i]
                c.drawText(s, origin: textPoint, fontName:"Monaco", fontSize: 10)
                
            }
            
        }
        
        var repoStartIndex = 0
        
        for (repo, jsonPath) in repoTuples {
            
            guard let data = NSData(contentsOfFile: jsonPath) else {
                print("-- no data in \(jsonPath)")
                continue
            }
            guard let optJSON = try? NSJSONSerialization.JSONObjectWithData(data, options: .MutableLeaves) as? AddedRemovedForAuthorForDate else {
                return
            }
            guard let json = optJSON else {
                return
            }
            
            // TODO: simplify this
            var authorsInRepoSet = Set<String>()
            let keys = json.values.flatMap({ $0.keys })
            for k in keys {
                authorsInRepoSet.insert(k)
            }
            let authorsInRepo = Array(authorsInRepoSet).sort()
            
            // draw repo name
            c.drawText(repo, origin: P(LEFT_MARGIN_WIDTH, c.height() - Constants.TOP_MARGIN_HEIGTH - (repoStartIndex) * ROW_HEIGHT - 18), fontName: "Monaco", fontSize: 10)
            
            repoStartIndex += 1
            
            // draw authors
            if let (_, weekday_offset) = sortedDayInfo.last {
                let (_, offset) = weekday_offset
                
                for (authorIndex, author) in authorsInRepo.enumerate() {
                    // draw author name
                    c.drawText(
                        author,
                        origin: P(LEFT_MARGIN_WIDTH + offset + Constants.COL_WIDTH + 18, c.height() - Constants.TOP_MARGIN_HEIGTH - (repoStartIndex+authorIndex) * ROW_HEIGHT - 15),
                        fontName: "Monaco",
                        fontSize: 10)
                    
                }
            }
            
            // draw background rectangles
            
            for (_, t) in sortedDayInfo {
                
                let (weekDay, offset) = t
                
                if weekDay == 1 || weekDay == 2 { continue }
                
                for (i, _) in authorsInRepo.enumerate() {
                    if let rect = rectForDay (
                        offset,
                        rowIndex: repoStartIndex+i,
                        canvasHeight: c.height()
                        ) {
                            let fillColor = NSColor.clearColor()
                            
                            c.drawRectangle(rect, strokeColor: NSColor.lightGrayColor(), fillColor: fillColor)
                    }
                }
            }
            
            // draw activity rectangles
            for (day, authorsDict) in json {
                
                for (author, addedRemovedDict) in authorsDict {
                    
                    // print("    ", author)
                    // print("        ", addedRemovedDict["added"])
                    // print("        ", addedRemovedDict["removed"])
                    
                    var linesChanged = 0
                    
                    if let added = addedRemovedDict["added"] {
                        linesChanged += added
                    }
                    
                    if let removed = addedRemovedDict["removed"] {
                        linesChanged += removed
                    }
                    
                    if let (weekDay, offset) = daysInfo[day], indexOfAuthor = authorsInRepo.indexOf(author) {
                        
                        if (weekDay == 1 || weekDay == 2) { continue }
                        
                        if let rect = rectForDay(
                            offset,
                            rowIndex: repoStartIndex+indexOfAuthor,
                            canvasHeight: c.height()
                            ) {
                                let fillColor = fillColorForLineCountPerDay(linesChanged, baseColor:colorForAuthor(author))
                                
                                c.drawRectangle(rect, strokeColor: NSColor.lightGrayColor(), fillColor: fillColor)
                        }
                    }
                }
            }
            
            repoStartIndex += authorsInRepo.count
        }
        
        c.saveAtPath(outPath)
    }
}
