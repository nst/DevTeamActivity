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
    
    let fiveLinesThresholds = [0, 1000, 2500, 4000, 5000]
    
    let weekDaysToSkip = [1,2] // Saturday, Sunday
    
    var dateFormatter: NSDateFormatter = {
        let df = NSDateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = NSTimeZone(name:"GMT")
        return df
    }()
    
    func daysTuplesFromDay(fromDay:String, toDay:String) -> [(day:String, weekDay:Int, offset:Int)] {
        
        let calendar = NSCalendar.currentCalendar()
        
        var daysInfo : [(day:String, weekDay:Int, offset:Int)] = []
        
        let matchingComponents = NSDateComponents()
        matchingComponents.hour = 0
        
        guard let fromDate = self.dateFormatter.dateFromString(fromDay) else { assertionFailure(); return [] }
        guard let toDate = self.dateFormatter.dateFromString(toDay) else { assertionFailure(); return [] }
        
        var xOffset = 0
        
        calendar.enumerateDatesStartingAfterDate(fromDate, matchingComponents: matchingComponents, options: .MatchStrictly) { (date: NSDate?, exactMatch: Bool, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
            
            guard let existingDate = date else { assertionFailure(); return }
            
            let day = self.dateFormatter.stringFromDate(existingDate)
            
            let weekDay = calendar.component(.Weekday, fromDate:existingDate)
            
            daysInfo.append((day, weekDay, xOffset))
            
            xOffset += self.weekDaysToSkip.contains(weekDay) ? 2 : self.COL_WIDTH
            
            if existingDate.compare(toDate) != NSComparisonResult.OrderedAscending {
                stop.memory = true
            }
        }
        
        return daysInfo
    }
    
    func rectForDay(offset:Int, rowIndex:Int, canvasHeight:Int) -> Rect {
        
        let p = P(
            self.LEFT_MARGIN_WIDTH + offset,
            canvasHeight - self.TOP_MARGIN_HEIGTH - (rowIndex+1) * self.ROW_HEIGHT
        )
        
        return Rect(p, width:self.COL_WIDTH, height:self.ROW_HEIGHT)
    }
    
    func fillColorForLineCountPerDay(count:Int, baseColor:NSColor) -> NSColor {
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
            let color = Chart.colorPalette.popLast() ?? NSColor.darkGrayColor()
            Chart.colorForAuthors[author] = color
        }
        
        return Chart.colorForAuthors[author]!
    }
    
    func drawLegend(c:Canvas, x:Int) {
        
        // draw title
        c.drawText("Number of Lines Changed", origin: P(x + 10, c.height() - 25))
        
        let numberOfLines = [
            "\(fiveLinesThresholds[0])",
            "\(fiveLinesThresholds[0])+",
            "\(fiveLinesThresholds[1])+",
            "\(fiveLinesThresholds[2])+",
            "\(fiveLinesThresholds[3])+",
            "\(fiveLinesThresholds[4])+"
        ]
        
        for i in 0...fiveLinesThresholds.count {
            let origin = P(x + 10 + i/3 * 80, c.height() - 15 - COL_WIDTH - (i%3+1) * self.ROW_HEIGHT)
            let r = Rect(origin, width: COL_WIDTH, height: self.ROW_HEIGHT)
            let intensity = CGFloat(i) * 0.2
            let fillColor = NSColor.grayColor().colorWithAlphaComponent(intensity)
            
            c.drawRectangle(r, strokeColor: NSColor.lightGrayColor(), fillColor: fillColor)
            
            let textPoint = P(origin.x + COL_WIDTH + 10, origin.y + 4)
            let s = numberOfLines[i]
            c.drawText(s, origin: textPoint)
        }
    }
    
    func drawTimeline(fromDay fromDay:String, toDay:String, repoTuples:[(repo:String, jsonPath:String)], outPath:String) throws {
        
        guard let c = Canvas(880,560, backgroundColor: NSColor.whiteColor()) else {
            assertionFailure()
            return
        }
        
        let dayTuples = daysTuplesFromDay(fromDay, toDay:toDay).filter( { weekDaysToSkip.contains($0.weekDay) == false } )
        
        // draw days
        for (day, _, offset) in dayTuples {
            let p = P(LEFT_MARGIN_WIDTH + offset, c.height() - self.TOP_MARGIN_HEIGTH)
            c.drawText("\(day)", origin: P(p.x-13, p.y+35), rotationAngle: CGFloat(M_PI/2.0))
        }
        
        // find legend x position
        guard let (_, _, offset) = dayTuples.last else { assertionFailure("period must be at least 1 day"); return }
        let legendAndAuthorsXPosition = LEFT_MARGIN_WIDTH + offset + COL_WIDTH + 18
        
        // draw legend
        self.drawLegend(c, x: legendAndAuthorsXPosition)
        
        var currentRow = 0
        
        // for each repo
        for (repo, jsonPath) in repoTuples {
            
            guard let
                data = NSData(contentsOfFile: jsonPath),
                optJSON = try? NSJSONSerialization.JSONObjectWithData(data, options: .MutableLeaves) as? AddedRemovedForAuthorForDate,
                json = optJSON else {
                    print("-- can't read data in \(jsonPath)")
                    return
            }
            
            let authorsInRepo = Array(Set(json.values.flatMap({ $0.keys }))).sort()
            
            // draw repo name
            c.drawText(repo, origin: P(LEFT_MARGIN_WIDTH, c.height() - self.TOP_MARGIN_HEIGTH - (currentRow) * ROW_HEIGHT - 18))
            
            currentRow += 1
            
            // draw authors
            for (authorIndex, author) in authorsInRepo.enumerate() {
                c.drawText(
                    author,
                    origin: P(legendAndAuthorsXPosition, c.height() - self.TOP_MARGIN_HEIGTH - (currentRow+authorIndex) * ROW_HEIGHT - 15))
            }
            
            // draw cells
            
            // for each author in the repo
            for (i, author) in authorsInRepo.enumerate() {
                
                // for each day of the timeframe
                for (day, _, offset) in dayTuples {
                    
                    // set default color
                    var fillColor = NSColor.clearColor()
                    
                    if let addedRemoved = json[day]?[author] {
                        // that day, this author commited changes in the repo
                        // set the cell color accordingly
                        
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
