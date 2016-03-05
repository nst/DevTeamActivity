//
//  ChartWeek.swift
//  hgReport
//
//  Created by Nicolas Seriot on 09/02/16.
//  Copyright © 2016 seriot.ch. All rights reserved.
//

import Cocoa

struct ChartMonth {
    
    let COL_WIDTH : CGFloat = 16
    let ROW_HEIGHT : CGFloat = 16
    let LEFT_MARGIN_WIDTH : CGFloat = 20
    let TOP_MARGIN_HEIGTH : CGFloat = 80
    
    let fiveLinesThresholds = [0, 1500, 3000, 6000, 15000]
    
    var dateFormatter: NSDateFormatter = {
        let df = NSDateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = NSTimeZone(name:"GMT")
        return df
    }()
    
    var monthYearDateFormatter: NSDateFormatter = {
        let df = NSDateFormatter()
        df.dateFormat = "yyyy-MM"
        df.timeZone = NSTimeZone(name:"GMT")
        return df
    }()
    
    func monthYearTuplesFromDay(fromDay:String, toDay:String) -> [(monthYear:String, offset:CGFloat)] {
        
        let calendar = NSCalendar.currentCalendar()
        
        var monthYearInfo : [(monthYear:String, offset:CGFloat)] = []
        
        let matchingComponents = NSDateComponents()
        matchingComponents.day = 1
        
        guard let fromDate = self.dateFormatter.dateFromString(fromDay) else { assertionFailure(); return [] }
        guard let toDate = self.dateFormatter.dateFromString(toDay) else { assertionFailure(); return [] }
        
        var xOffset : CGFloat = 0
        
        calendar.enumerateDatesStartingAfterDate(fromDate, matchingComponents: matchingComponents, options: .MatchStrictly) { (date: NSDate?, exactMatch: Bool, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
            
            guard let existingDate = date else { assertionFailure(); return }
            
            let monthYear = self.monthYearDateFormatter.stringFromDate(existingDate)
            
            monthYearInfo.append((monthYear, xOffset))
            
            xOffset += self.COL_WIDTH
            
            if monthYear.hasSuffix("-12") {
                xOffset += 4
            }
            
            if existingDate.compare(toDate) != NSComparisonResult.OrderedAscending {
                stop.memory = true
            }
        }
        
        return monthYearInfo
    }
    
    func monthYearAuthorChangesDictionaryFromJSON(json:AddedRemovedForAuthorForDate) -> [String:[String:Int]] {
        
        // read json and build new structure aggregated by months
        
        var monthYearDictionary : [String:[String:Int]] = [:] // [dayMonth:[author:changes]]
        
        for (day, addedRemovedForAuthorDictionary) in json {
            //print(day, addedRemovedForAuthorDictionary)
            
            let monthYear = (day as NSString).substringToIndex(7)
            
            if monthYearDictionary[monthYear] == nil {
                monthYearDictionary[monthYear] = [:]
            }
            
            for (author, addedRemoved) in addedRemovedForAuthorDictionary {
                // that day, this author commited changes in the repo
                // add the number of lines changed into monthYearDictionary
                
                var linesChanged = 0
                linesChanged += addedRemoved["added"] ?? 0
                linesChanged += addedRemoved["removed"] ?? 0
                
                //
                
                if monthYearDictionary[monthYear] == nil {
                    monthYearDictionary[monthYear] = [:] // [author:changes]
                }
                
                if monthYearDictionary[monthYear]![author] == nil {
                    monthYearDictionary[monthYear]![author] = 0
                }
                
                monthYearDictionary[monthYear]![author]! += linesChanged
            }
        }
        
        return monthYearDictionary
    }
    
    func rectForDay(offset:CGFloat, rowIndex:Int) -> NSRect {
        
        let x = self.LEFT_MARGIN_WIDTH + offset
        let y = self.TOP_MARGIN_HEIGTH + rowIndex * self.ROW_HEIGHT
        
        return NSMakeRect(x, y, self.COL_WIDTH, self.ROW_HEIGHT)
    }
    
    func fillColorForLineCountPerMonth(count:Int, baseColor:NSColor) -> NSColor {
        var intensity : CGFloat
        
        switch(count) {
        case count where count > fiveLinesThresholds[4]: intensity = 1.0
        case count where count > fiveLinesThresholds[3]: intensity = 0.8
        case count where count > fiveLinesThresholds[2]: intensity = 0.6
        case count where count > fiveLinesThresholds[1]: intensity = 0.4
        case count where count > fiveLinesThresholds[0]: intensity = 0.2
        default: intensity = 0.0
        }
        
        return baseColor.colorWithAlphaComponent(intensity)
    }
    
    static var colorForAuthors : [String:NSColor] = [:]
    
    func colorForAuthor(author:String) -> NSColor {
        
        if (author as NSString).hasSuffix("@apple.com") {
            return NSColor.orangeColor()
        }
        return NSColor.darkGrayColor()
    }
    
    func drawLegend(bc:BitmapCanvas, x:CGFloat) {
        
        // draw title
        bc.text("Number of Lines Changed", P(x + 10, 10))
        
        let numberOfLines = [
            "\(fiveLinesThresholds[0])",
            "\(fiveLinesThresholds[0])+",
            "\(fiveLinesThresholds[1])+",
            "\(fiveLinesThresholds[2])+",
            "\(fiveLinesThresholds[3])+",
            "\(fiveLinesThresholds[4])+"
        ]
        
        for i in 0...fiveLinesThresholds.count {
            let p = P(x + 10 + i/3 * 80, COL_WIDTH + (i%3+1) * self.ROW_HEIGHT - 10)
            let r = NSMakeRect(p.x, p.y, self.COL_WIDTH, self.ROW_HEIGHT)
            let intensity = i * 0.2
            let fillColor = NSColor.orangeColor().colorWithAlphaComponent(intensity)
            
            bc.rectangle(r, strokeColor: NSColor.lightGrayColor(), fillColor: fillColor)
            
            let textPoint = P(p.x + COL_WIDTH + 10, p.y + 6)
            let s = numberOfLines[i]
            bc.text(s, textPoint)
        }
    }
    
    func linesChangedByAuthor(monthYearAuthorChangesDictionary:[String:[String:Int]]) -> [String:Int] {
        var linesChangedByAuthor : [String:Int] = [:]
        for (monthYear, linesChangedByAuthorThatMonth) in monthYearAuthorChangesDictionary {
            for (author, linesChanged) in linesChangedByAuthorThatMonth {
                if linesChangedByAuthor[author] == nil {
                    linesChangedByAuthor[author] = 0
                }
                linesChangedByAuthor[author]! += linesChanged
            }
        }
        return linesChangedByAuthor
    }
    
    func drawTimeline(fromDay fromDay:String, toDay:String, repoTuples:[(repo:String, jsonPath:String)], outPath:String) throws {
        
        let bitmapCanvas = BitmapCanvas(1400,5700, backgroundColor: NSColor.whiteColor())
        
        let monthYearTuples = monthYearTuplesFromDay(fromDay, toDay:toDay)
        
        // draw days
        for (monthYear, offset) in monthYearTuples {
            let p = P(LEFT_MARGIN_WIDTH + offset, TOP_MARGIN_HEIGTH - 10)
            bitmapCanvas.text("\(monthYear)", P(p.x+7, p.y), rotationDegrees:-90)
        }
        
        // find legend x position
        guard let (monthYear, offset) = monthYearTuples.last else { assertionFailure("period must be at least 1 day"); return }
        let legendAndAuthorsXPosition = LEFT_MARGIN_WIDTH + offset + COL_WIDTH + 18
        
        // draw title
        bitmapCanvas.text("https://github.com/apple/swift", P(450, 10))
        
        // draw legend
        self.drawLegend(bitmapCanvas, x: legendAndAuthorsXPosition)
        
        var currentRow = 0
        
        // for each repo
        for (repoName, jsonPath) in repoTuples {
            
            guard let
                data = NSData(contentsOfFile: jsonPath),
                optJSON = try? NSJSONSerialization.JSONObjectWithData(data, options: .MutableLeaves) as? AddedRemovedForAuthorForDate,
                json = optJSON else {
                    print("-- can't read data in \(jsonPath)")
                    return
            }

            let monthYearAuthorChangesDictionary = monthYearAuthorChangesDictionaryFromJSON(json)
            
            let linesByAuthor = linesChangedByAuthor(monthYearAuthorChangesDictionary)
            
            let sortedAuthors = Array(linesByAuthor.keys).sort({ linesByAuthor[$0] > linesByAuthor[$1] })
            
            // draw authors
            for (authorIndex, author) in sortedAuthors.enumerate() {
                bitmapCanvas.text(
                    "\(author) (\(linesByAuthor[author]!))",
                    P(legendAndAuthorsXPosition, self.TOP_MARGIN_HEIGTH + (currentRow+authorIndex) * ROW_HEIGHT + 5))
            }
            
            // draw cells
            
            // for each author in the repo
            for (i, author) in sortedAuthors.enumerate() {
                
                // for each month of the timeframe
                for (monthYear, offset) in monthYearTuples {
                    
                    // set default color
                    var fillColor = NSColor.clearColor()
                    
                    if let linesChanged = monthYearAuthorChangesDictionary[monthYear]?[author] {
                        // that day, this author commited changes in the repo
                        // set the cell color accordingly
                        
                        fillColor = fillColorForLineCountPerMonth(linesChanged, baseColor:colorForAuthor(author))
                    }
                    
                    let rect = rectForDay (offset, rowIndex: currentRow+i)
                    bitmapCanvas.rectangle(rect, strokeColor: NSColor.lightGrayColor(), fillColor: fillColor)
                }
            }
            
            currentRow += sortedAuthors.count
        }
        
        let currentDateString = dateFormatter.stringFromDate(NSDate()) // FIXME: doesn't consider timezones
        
        bitmapCanvas.text("Generated by Nicolas Seriot on \(currentDateString) with https://github.com/nst/DevTeamActivity", P(LEFT_MARGIN_WIDTH, self.TOP_MARGIN_HEIGTH + currentRow * ROW_HEIGHT + 10))
        
        bitmapCanvas.save(outPath)
    }
}
