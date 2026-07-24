#import <AppKit/AppKit.h>

static void drawLayer(CGFloat centerY, NSColor *strokeColor, CGFloat strokeWidth) {
    NSBezierPath *layer = [NSBezierPath bezierPath];
    [layer moveToPoint:NSMakePoint(276, centerY + 36)];
    [layer curveToPoint:NSMakePoint(748, centerY + 36)
           controlPoint1:NSMakePoint(276, centerY - 52)
           controlPoint2:NSMakePoint(748, centerY - 52)];
    layer.lineWidth = strokeWidth;
    layer.lineCapStyle = NSLineCapStyleRound;
    [strokeColor setStroke];
    [layer stroke];
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) {
            fprintf(stderr, "Usage: render-icon OUTPUT.png\n");
            return 2;
        }

        NSSize canvasSize = NSMakeSize(1024, 1024);
        NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
            initWithBitmapDataPlanes:NULL
            pixelsWide:(NSInteger)canvasSize.width
            pixelsHigh:(NSInteger)canvasSize.height
            bitsPerSample:8
            samplesPerPixel:4
            hasAlpha:YES
            isPlanar:NO
            colorSpaceName:NSDeviceRGBColorSpace
            bytesPerRow:0
            bitsPerPixel:0];
        if (bitmap == nil) {
            fprintf(stderr, "Could not create icon bitmap.\n");
            return 1;
        }

        NSGraphicsContext *graphics = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
        if (graphics == nil) {
            fprintf(stderr, "Could not create icon graphics context.\n");
            return 1;
        }

        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:graphics];
        graphics.imageInterpolation = NSImageInterpolationHigh;

        [[NSColor clearColor] setFill];
        [NSBezierPath fillRect:NSMakeRect(0, 0, canvasSize.width, canvasSize.height)];

        NSBezierPath *background = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(72, 72, 880, 880) xRadius:204 yRadius:204];
        NSColor *backgroundStart = [NSColor colorWithCalibratedRed:0.082 green:0.137 blue:0.247 alpha:1];
        NSColor *backgroundMiddle = [NSColor colorWithCalibratedRed:0.141 green:0.329 blue:0.553 alpha:1];
        NSColor *backgroundEnd = [NSColor colorWithCalibratedRed:0.086 green:0.651 blue:0.631 alpha:1];
        NSGradient *backgroundGradient = [[NSGradient alloc]
            initWithColorsAndLocations:
                backgroundStart, (CGFloat)0,
                backgroundMiddle, (CGFloat)0.55,
                backgroundEnd, (CGFloat)1,
                nil];
        [backgroundGradient drawInBezierPath:background angle:-48];

        NSColor *white = [NSColor colorWithCalibratedRed:0.973 green:0.984 blue:1 alpha:1];
        CGFloat strokeWidth = 42;

        NSBezierPath *body = [NSBezierPath bezierPath];
        [body moveToPoint:NSMakePoint(276, 670)];
        [body lineToPoint:NSMakePoint(276, 354)];
        [body curveToPoint:NSMakePoint(748, 354)
             controlPoint1:NSMakePoint(276, 288)
             controlPoint2:NSMakePoint(748, 288)];
        [body lineToPoint:NSMakePoint(748, 670)];
        body.lineWidth = strokeWidth;
        body.lineJoinStyle = NSLineJoinStyleRound;
        [[white colorWithAlphaComponent:0.2] setFill];
        [white setStroke];
        [body fill];
        [body stroke];

        NSBezierPath *top = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(276, 550, 472, 240)];
        top.lineWidth = strokeWidth;
        [[white colorWithAlphaComponent:0.24] setFill];
        [white setStroke];
        [top fill];
        [top stroke];

        drawLayer(474, white, strokeWidth);
        drawLayer(316, white, strokeWidth);

        NSColor *queryColor = [NSColor colorWithCalibratedRed:0.4 green:0.89 blue:0.84 alpha:1];
        NSBezierPath *chevron = [NSBezierPath bezierPath];
        [chevron moveToPoint:NSMakePoint(392, 576)];
        [chevron lineToPoint:NSMakePoint(474, 506)];
        [chevron lineToPoint:NSMakePoint(392, 436)];
        chevron.lineWidth = 38;
        chevron.lineCapStyle = NSLineCapStyleRound;
        chevron.lineJoinStyle = NSLineJoinStyleRound;
        [queryColor setStroke];
        [chevron stroke];

        NSBezierPath *underscore = [NSBezierPath bezierPath];
        [underscore moveToPoint:NSMakePoint(524, 436)];
        [underscore lineToPoint:NSMakePoint(640, 436)];
        underscore.lineWidth = 38;
        underscore.lineCapStyle = NSLineCapStyleRound;
        [queryColor setStroke];
        [underscore stroke];

        [graphics flushGraphics];
        [NSGraphicsContext restoreGraphicsState];

        NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        if (png == nil || ![png writeToFile:[NSString stringWithUTF8String:argv[1]] atomically:YES]) {
            fprintf(stderr, "Could not write icon PNG.\n");
            return 1;
        }
    }
    return 0;
}
