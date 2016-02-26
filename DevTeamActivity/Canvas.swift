//
//  main.swift
//  Canvas
//
//  Created by nst on 04/01/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import Cocoa

typealias P = Point

struct Point {
    
    let x : Int
    let y : Int
    
    init(_ x:Int, _ y:Int) {
        self.x = x
        self.y = y
    }
    
    var NSPoint : CGPoint {
        return NSMakePoint(CGFloat(self.x), CGFloat(self.y))
    }
}

struct Rect {
    
    let origin : Point
    let width : Int
    let height : Int
    
    init(_ origin:Point, width:Int, height:Int) {
        self.origin = origin
        self.width = width
        self.height = height
    }
    
    var NSRect : CGRect {
        return NSMakeRect(CGFloat(origin.x), CGFloat(origin.y), CGFloat(width), CGFloat(height))
    }
}

struct Canvas {
    
    let bitmapImageRep : NSBitmapImageRep
    let context : NSGraphicsContext
    
    var cgContext : CGContext {
        return context.CGContext
    }
    
    var width : Int {
        return Int(bitmapImageRep.size.width)
    }
    
    var height : Int {
        return Int(bitmapImageRep.size.height)
    }
    
    func setAllowsAntialiasing(antialiasing : Bool) {
        CGContextSetAllowsAntialiasing(cgContext, antialiasing)
    }
    
    init?(_ width:Int, _ height:Int, backgroundColor:NSColor? = nil) {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,
            pixelsWide:width,
            pixelsHigh:height,
            bitsPerSample:8,
            samplesPerPixel:4,
            hasAlpha:true,
            isPlanar:false,
            colorSpaceName:NSDeviceRGBColorSpace,
            bytesPerRow:0,
            bitsPerPixel:0)
        
        guard let existingBitmap = bitmap else { return nil }
        
        self.bitmapImageRep = existingBitmap
        
        let context = NSGraphicsContext(bitmapImageRep: existingBitmap)
        
        guard let existingContext = context else { return nil }
        
        self.context = existingContext
        
        NSGraphicsContext.setCurrentContext(context)
        
        setAllowsAntialiasing(false)
        
        if let color = backgroundColor {
            let rect = Rect(P(0,0), width: width, height: height)
            drawRectangle(rect, strokeColor: color, fillColor: color)
        }
        
        // coordinates start upper left
        CGContextTranslateCTM(context!.CGContext, 0.0, CGFloat(height))
        CGContextScaleCTM(context!.CGContext, 1.0, -1.0)
    }
    
    func drawLineFromPoint(p1:Point, toPoint p2:Point) {
        NSBezierPath.strokeLineFromPoint(p1.NSPoint, toPoint:p2.NSPoint)
    }
    
    func drawVerticalLine(p p1:Point, deltaY:Int) {
        let p2 = Point(p1.x, p1.y + deltaY)
        self.drawLineFromPoint(p1, toPoint: p2)
    }
    
    func drawHorizontalLine(p p1:Point, deltaX:Int) {
        let p2 = Point(p1.x + deltaX, p1.y)
        self.drawLineFromPoint(p1, toPoint: p2)
    }
    
    func drawLineFromPoint(p1:Point, deltaX:Int, deltaY:Int) {
        let p2 = Point(p1.x + deltaX, p1.y + deltaY)
        self.drawLineFromPoint(p1, toPoint: p2)
    }
    
    func drawRectangle(rect:Rect) {
        NSBezierPath.strokeRect(rect.NSRect)
    }
    
    func drawRectangle(rect:Rect, strokeColor:NSColor, fillColor:NSColor) {
        context.saveGraphicsState()
        
        fillColor.setFill()
        NSBezierPath.fillRect(rect.NSRect)
        
        strokeColor.setStroke()
        NSBezierPath.strokeRect(rect.NSRect)

        context.restoreGraphicsState()
    }
    
    func saveAtPath(path:String) -> Bool {
        if let data = bitmapImageRep.representationUsingType(NSBitmapImageFileType.NSPNGFileType, properties: [:]) {
            return data.writeToFile(path, atomically: false)
        }
        return false
    }
    
    func textWidth(text:NSString, font:NSFont) -> CGFloat {
        let maxSize : CGSize = CGSizeMake(CGFloat.max, font.pointSize)
        let textRect : CGRect = text.boundingRectWithSize(
            maxSize,
            options: NSStringDrawingOptions.UsesLineFragmentOrigin,
            attributes: [NSFontAttributeName: font],
            context: nil)
        return textRect.size.width
    }
    
    func drawImageAtPath(path:String, origin:Point) {
        context.saveGraphicsState()
        
        let data = NSData(contentsOfFile:path)
        let imgRep = NSBitmapImageRep(data: data!)
        
        CGContextScaleCTM(cgContext, 1.0, -1.0)
        CGContextTranslateCTM(cgContext, 0.0, CGFloat(-2.0 * (Double(origin.y))) - CGFloat(imgRep!.pixelsHigh))
        
        imgRep?.drawInRect(NSMakeRect(CGFloat(origin.x), CGFloat(origin.y), CGFloat(imgRep!.pixelsWide), CGFloat(imgRep!.pixelsHigh)))
        
        context.restoreGraphicsState()
    }
    
    func drawText(text:String, origin:Point, fontName:String = "Monaco", fontSize:Int = 10, rotationRadians:CGFloat = 0.0) {
        
        let p = origin.NSPoint
        
        guard let existingFont = NSFont(name: fontName, size: CGFloat(fontSize)) else { return }
        
        let attr = [
            NSFontAttributeName:existingFont,
            NSForegroundColorAttributeName:NSColor.blackColor()
        ]
        
        context.saveGraphicsState()
        
        if(rotationRadians != 0.0) {
            let width = textWidth(text, font:existingFont)
            CGContextTranslateCTM(cgContext, p.x + width / 2.0, p.y);
            CGContextRotateCTM(cgContext, rotationRadians)
            CGContextTranslateCTM(cgContext, -p.x - width / 2.0, -p.y);
        }
        
        CGContextScaleCTM(cgContext, 1.0, -1.0)
        CGContextTranslateCTM(cgContext, 0.0, CGFloat(-2.0 * Double(origin.y) - Double(fontSize)))
        
        text.drawAtPoint(p, withAttributes: attr)
        
        context.restoreGraphicsState()
    }
}
