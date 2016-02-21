//
//  ChartWeek.swift
//  hgReport
//
//  Created by Nicolas Seriot on 09/02/16.
//  Copyright © 2016 seriot.ch. All rights reserved.
//

import Cocoa

infix operator +=? { associativity right precedence 90 }
func +=? (inout left: Int, right: Int?) {
    if let existingRight = right {
        left = left + existingRight
    }
}

struct Chart {
    
    let COL_WIDTH = 20
    let ROW_HEIGHT = 20
    let LEFT_MARGIN_WIDTH = 20
    let TOP_MARGIN_HEIGTH = 100
    
    let weekDaysToSkip = [1,2] // Saturday, Sunday
    
    var dateFormatter: NSDateFormatter = {
        let df = NSDateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = NSTimeZone(name:"GMT")
        return df
    }()
    
    func daysInfoFromDay(fromDay:String, toDay:String) -> [String:(day:String, weekDay:Int, offset:Int)] {
        
        let calendar = NSCalendar.currentCalendar()
        
        var daysInfo : [String:(day:String, weekDay:Int, offset:Int)] = [:]
        
        let matchingComponents = NSDateComponents()
        matchingComponents.hour = 0
        
        guard let fromDate = self.dateFormatter.dateFromString(fromDay) else { assertionFailure(); return [:] }
        guard let toDate = self.dateFormatter.dateFromString(toDay) else { assertionFailure(); return [:] }
        
        var offset = 0
        
        calendar.enumerateDatesStartingAfterDate(fromDate, matchingComponents: matchingComponents, options: .MatchStrictly) { (date: NSDate?, exactMatch: Bool, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
            
            guard let existingDate = date else { assertionFailure(); return }
            
            let day = self.dateFormatter.stringFromDate(existingDate)
            
            let weekDay = calendar.component(.Weekday, fromDate:existingDate)
            
            daysInfo[day] = (day, weekDay, offset)
            
            let isDayOff = (weekDay == 1 || weekDay == 2)
            offset += isDayOff ? 2 : self.COL_WIDTH
            
            if existingDate.compare(toDate) != NSComparisonResult.OrderedAscending {
                stop.memory = true
            }
        }
        
        return daysInfo
    }
    
    func rectForDay(offset:Int, rowIndex:Int, canvasHeight:Int) -> Rect {
        
        let COL_WIDTH = self.COL_WIDTH
        let ROW_HEIGHT = self.ROW_HEIGHT
        let LEFT_MARGIN_WIDTH = self.LEFT_MARGIN_WIDTH
        let TOP_MARGIN_HEIGTH = self.TOP_MARGIN_HEIGTH
        
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
    
    func drawLegend(c:Canvas, x:Int) {
        
        // draw title
        c.drawText("Number of Lines Changed", origin: P(x + 10, c.height() - 25), fontName: "Monaco", fontSize: 10)
        
        let numberOfLines = ["0", "0+", "1000+", "2500+", "4000+", "5000+"]
        
        for i in 0...5 {
            let origin = P(x + 10 + i/3 * 80, c.height() - 15 - COL_WIDTH - (i%3+1) * self.ROW_HEIGHT)
            let r = Rect(origin, width: COL_WIDTH, height: self.ROW_HEIGHT)
            let intensity = CGFloat(i) * 0.2
            let color = NSColor.grayColor().colorWithAlphaComponent(intensity)
            
            c.drawRectangle(r, strokeColor: NSColor.lightGrayColor(), fillColor: color)
            
            let textPoint = P(origin.x + COL_WIDTH + 10, origin.y + 4)
            let s = numberOfLines[i]
            c.drawText(s, origin: textPoint, fontName:"Monaco", fontSize: 10)
        }
        
    }
    
    func drawTimeline(fromDay fromDay:String, toDay:String, repoTuples:[(repo:String, jsonPath:String)], outPath:String) throws {
        
        guard let c = Canvas(880,560, backgroundColor: NSColor.whiteColor()) else {
            assertionFailure()
            return
        }
        
        let daysInfo = daysInfoFromDay(fromDay, toDay:toDay)
        
        let sortedDayInfo = daysInfo.sort { return $0.0 < $1.0 }
        
        // draw days
        for (_, v) in daysInfo {
            let (day, weekDay, offset) = v
            if (weekDay == 1 || weekDay == 2) { continue }
            let p = P(LEFT_MARGIN_WIDTH + offset, c.height() - self.TOP_MARGIN_HEIGTH)
            c.drawText("\(day)", origin: P(p.x-13, p.y+35), fontName: "Monaco", fontSize: 10, rotationAngle: CGFloat(M_PI/2.0))
        }
        
        // find legend x position
        guard let (_, (_, _, offset)) = sortedDayInfo.last else { assertionFailure("period must be at least 1 day"); return }
        let legendAndAuthorsXPosition = LEFT_MARGIN_WIDTH + offset + COL_WIDTH + 18
        
        // draw legend
        self.drawLegend(c, x: legendAndAuthorsXPosition)
        
        var currentRow = 0
        
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
            
            let authorsInRepoSet = Set(json.values.flatMap({ $0.keys }))
            let authorsInRepo = Array(authorsInRepoSet).sort()
            
            // draw repo name
            c.drawText(repo, origin: P(LEFT_MARGIN_WIDTH, c.height() - self.TOP_MARGIN_HEIGTH - (currentRow) * ROW_HEIGHT - 18), fontName: "Monaco", fontSize: 10)
            
            currentRow += 1
            
            // draw authors
            for (authorIndex, author) in authorsInRepo.enumerate() {
                // draw author name
                c.drawText(
                    author,
                    origin: P(legendAndAuthorsXPosition, c.height() - self.TOP_MARGIN_HEIGTH - (currentRow+authorIndex) * ROW_HEIGHT - 15),
                    fontName: "Monaco",
                    fontSize: 10)
            }
            
            // draw cells
            let weekDayOffsetTuples = sortedDayInfo.filter( { weekDaysToSkip.contains($0.1.1) == false } )
            
            // for each day of the timeframe
            for (_,v) in weekDayOffsetTuples {
                let (day, _, offset) = v
                
                // for each author in the repo
                for (i, author) in authorsInRepo.enumerate() {
                    
                    // set default color
                    var fillColor = NSColor.clearColor()
                    
                    if let addedRemoved = json[day]?[author] {
                        // data exist for this day and authod
                        // change default color accordingly
                        
                        var linesChanged = 0
                        
                        linesChanged +=? addedRemoved["added"]
                        linesChanged +=? addedRemoved["removed"]
                        
                        fillColor = fillColorForLineCountPerDay(linesChanged, baseColor:colorForAuthor(author))
                    }
                    
                    let rect = rectForDay (offset, rowIndex: currentRow+i, canvasHeight: c.height())
                    c.drawRectangle(rect, strokeColor: NSColor.lightGrayColor(), fillColor: fillColor)
                }
            }
            
            currentRow += authorsInRepo.count
        }
        
        c.saveAtPath(outPath)
    }
}
