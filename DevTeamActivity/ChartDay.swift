//
//  ChartWeek.swift
//  hgReport
//
//  Created by Nicolas Seriot on 09/02/16.
//  Copyright © 2016 seriot.ch. All rights reserved.
//

import Cocoa

struct ChartDay {
    
    let COL_WIDTH : CGFloat = 20
    let ROW_HEIGHT : CGFloat = 20
    let LEFT_MARGIN_WIDTH : CGFloat = 20
    let TOP_MARGIN_HEIGTH : CGFloat = 100
    
    let fiveLinesThresholds = [0, 1000, 2500, 4000, 5000]
    
    let weekDaysToSkip = [1,2] // Saturday, Sunday
    
    var dateFormatter: NSDateFormatter = {
        let df = NSDateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = NSTimeZone(name:"GMT")
        return df
    }()
    
    func daysTuplesFromDay(fromDay:String, toDay:String) -> [(day:String, weekDay:Int, offset:CGFloat)] {
        
        let calendar = NSCalendar.currentCalendar()
        
        var daysInfo : [(day:String, weekDay:Int, offset:CGFloat)] = []
        
        let matchingComponents = NSDateComponents()
        matchingComponents.hour = 0
        
        guard let fromDate = self.dateFormatter.dateFromString(fromDay) else { assertionFailure(); return [] }
        guard let toDate = self.dateFormatter.dateFromString(toDay) else { assertionFailure(); return [] }
        
        var xOffset : CGFloat = 0
        
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
    
    func rectForDay(offset:CGFloat, rowIndex:Int) -> NSRect {
        
        let x = self.LEFT_MARGIN_WIDTH + offset
        let y = self.TOP_MARGIN_HEIGTH + rowIndex * self.ROW_HEIGHT
        
        return NSMakeRect(x, y, self.COL_WIDTH, self.ROW_HEIGHT)
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
        
        if ChartDay.colorForAuthors[author] == nil {
            let color = ChartDay.colorPalette.popLast() ?? NSColor.darkGrayColor()
            ChartDay.colorForAuthors[author] = color
        }
        
        return ChartDay.colorForAuthors[author]!
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
            let fillColor = NSColor.grayColor().colorWithAlphaComponent(intensity)
            
            bc.rectangle(r, stroke: NSColor.lightGrayColor(), fill: fillColor)
            
            let textPoint = P(p.x + COL_WIDTH + 10, p.y + 6)
            let s = numberOfLines[i]
            bc.text(s, textPoint)
        }
    }
    
    func drawTimeline(fromDay fromDay:String, toDay:String, repoTuples:[(repo:String, jsonPath:String)], outPath:String) throws {
        
        let bitmapCanvas = BitmapCanvas(880,560, "white")
        
        let dayTuples = daysTuplesFromDay(fromDay, toDay:toDay).filter( { weekDaysToSkip.contains($0.weekDay) == false } )
        
        // draw days
        for (day, _, offset) in dayTuples {
            let p = P(LEFT_MARGIN_WIDTH + offset, TOP_MARGIN_HEIGTH - 10)
            bitmapCanvas.text("\(day)", P(p.x+7, p.y), rotationDegrees:-90)
        }
        
        // find legend x position
        guard let (_, _, offset) = dayTuples.last else { assertionFailure("period must be at least 1 day"); return }
        let legendAndAuthorsXPosition = LEFT_MARGIN_WIDTH + offset + COL_WIDTH + 18
        
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
            
            let authorsInRepo = Array(Set(json.values.flatMap({ $0.keys }))).sort()
            
            // draw repo name
            bitmapCanvas.text(repoName, P(LEFT_MARGIN_WIDTH, self.TOP_MARGIN_HEIGTH + currentRow * ROW_HEIGHT + 7))
            
            currentRow += 1
            
            // draw authors
            for (authorIndex, author) in authorsInRepo.enumerate() {
                bitmapCanvas.text(
                    author,
                    P(legendAndAuthorsXPosition, self.TOP_MARGIN_HEIGTH + (currentRow+authorIndex) * ROW_HEIGHT + 5))
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
                        
                        linesChanged += addedRemoved["added"] ?? 0
                        linesChanged += addedRemoved["removed"] ?? 0
                        
                        fillColor = fillColorForLineCountPerDay(linesChanged, baseColor:colorForAuthor(author))
                    }
                    
                    let rect = rectForDay (offset, rowIndex: currentRow+i)
                    bitmapCanvas.rectangle(rect, stroke: NSColor.lightGrayColor(), fill: fillColor)
                }
            }
            
            currentRow += authorsInRepo.count
        }
        
        bitmapCanvas.save(outPath)
    }
}
