//
//  WeightControlQuartzPlotGLES.m
//  SelfHub
//
//  Created by Eugine Korobovsky on 03.08.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "WeightControlQuartzPlotGLES.h"
#import <QuartzCore/QuartzCore.h>
#import "WeightControlPlotRenderEngine.h"

#define RENDERER_TYPECAST(x) ((WeightControlPlotRenderEngine *)x)

@implementation WeightControlQuartzPlotGLES

@synthesize delegateWeight;


+ (Class)layerClass {
    return [CAEAGLLayer class];
};

- (id)initWithFrame:(CGRect)frame{
    return [self initWithFrame:frame andDelegate:nil];
};

- (id)initWithFrame:(CGRect)frame andDelegate:(WeightControl *)_delegate
{
    self = [super initWithFrame:frame];
    if (self) {
        delegateWeight = _delegate;
        if(delegateWeight==nil){
            NSLog(@"WeightControlQuartzPlotGLES: initialize with nil-value delegate!");
        }
        
        fpsStr = nil;
        
        CAEAGLLayer* eaglLayer = (CAEAGLLayer*) super.layer;
        eaglLayer.opaque = YES;
        BOOL isRetina = NO;
        if([[UIScreen mainScreen] scale]==2.0) isRetina = YES;
        eaglLayer.contentsScale = isRetina ? 2.0 : 1.0;
        contentScale = eaglLayer.contentsScale;
        plotContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
        if (!plotContext || ![EAGLContext setCurrentContext:plotContext]) {
            [self release];
            return nil;
        };
        
        NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
        [dateComponents setMonth:06];
        [dateComponents setDay:25];
        [dateComponents setYear:2012];
        [dateComponents setHour:0];
        [dateComponents setMinute:0];
        [dateComponents setSecond:0];
        NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        NSDate *firstDate = [gregorian dateFromComponents:dateComponents];
        [dateComponents release];
        [gregorian release];
        NSDate *lastDate = [NSDate date];

        
        
        myRender = CreateRendererForGLES1();
        [plotContext renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable: eaglLayer];
        RENDERER_TYPECAST(myRender)->Initialize(frame.size.width*eaglLayer.contentsScale, frame.size.height*eaglLayer.contentsScale);
        RENDERER_TYPECAST(myRender)->SetYAxisParams(70.0, 100.0, 1.5);
        
        RENDERER_TYPECAST(myRender)->SetXAxisParams([firstDate timeIntervalSince1970], [lastDate timeIntervalSince1970]);
        RENDERER_TYPECAST(myRender)->SetScaleX(1.0);
        RENDERER_TYPECAST(myRender)->SetOffsetTimeInterval(0.0);
        
        [self updatePlotLowLayerBase];
        
        //RENDERER_TYPECAST(myRender)->SetScaleY(0.95, false);
        
        
        
        
        drawingsCounter = 0;
        CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(drawView:)];
        [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        
        [self drawView:nil];
        
        timestamp = CACurrentMediaTime();
        
        tmpVal = false;
        
        // Adding gesture recognizers for user interaction support
        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGestureRecognizer:)];
        UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGestureRecognizer:)];
        [self addGestureRecognizer:panGesture];
        [self addGestureRecognizer:pinchGesture];
        [panGesture release];
        [pinchGesture release];
        

    }
    return self;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

- (void) drawView:(CADisplayLink*) displayLink{
    drawingsCounter++;
    if(drawingsCounter==60){
        //NSLog(@"OpenGL ES 1.1 plot's FPS: %.3f", 1.0 / displayLink.duration);
        drawingsCounter = 0;
    };
    
    if (displayLink != nil) {
        float elapsedSeconds = displayLink.timestamp - timestamp;
        timestamp = displayLink.timestamp;
        RENDERER_TYPECAST(myRender)->UpdateAnimation(elapsedSeconds);
    }
    
    RENDERER_TYPECAST(myRender)->Render();
    
    
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    glEnable(GL_TEXTURE_2D);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    
    // Y-Axis labels
    float firstGridPt, firstGridWeight, gridLinesStep, weightLinesStep;
    unsigned short linesNum;
    RENDERER_TYPECAST(myRender)->GetYAxisDrawParams(firstGridPt, firstGridWeight, gridLinesStep, weightLinesStep, linesNum);
    float i;
    NSString *weightStr = nil;
    Texture2D *weightLabel = nil;
    float fontSize;
    for(i=0;i<linesNum;i++){
        weightStr = [[NSString alloc] initWithFormat:@"%.1f", firstGridWeight + i*weightLinesStep];
        fontSize = ([weightStr length]>4 ? 11 : 12) * contentScale;
        weightLabel = [[Texture2D alloc] initWithString:weightStr dimensions:CGSizeMake(50*contentScale, 32) alignment:UITextAlignmentLeft fontName:@"Helvetica-Bold" fontSize:fontSize];
        [weightLabel drawAtPoint:CGPointMake(-(self.frame.size.width / 2.0-28) * contentScale, firstGridPt + i*gridLinesStep + 5*contentScale)];
        [weightLabel release];
        [weightStr release];
        
    };
    
    //FPS
    //glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    if(fpsStr==nil || drawingsCounter%30==0){
        if(fpsStr) [fpsStr release];
        fpsStr = [[NSString alloc] initWithFormat:@"%.0f fps", (float)(CLOCKS_PER_SEC / ((clock() - lastClock)))];
    };
    Texture2D *fpsLabel = [[Texture2D alloc] initWithString:fpsStr dimensions:CGSizeMake(320*contentScale, 32) alignment:NSTextAlignmentRight fontName:@"Helvetica" fontSize:10.0*contentScale];
    [fpsLabel drawAtPoint:CGPointMake(0.0, -(self.frame.size.height/2.0-30)*contentScale)];
    [fpsLabel release];
    
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glDisable(GL_BLEND);
    glDisable(GL_TEXTURE_2D);
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);
    glDisableClientState(GL_VERTEX_ARRAY);
    
    
    [plotContext presentRenderbuffer:GL_RENDERBUFFER_OES];
    
    
    if(drawingsCounter==60){
        drawingsCounter = 0;
    };
    lastClock = clock();
};

#pragma mark - Synchronization between layer-base and main application base

- (void)updatePlotLowLayerBase{
    std::list<WeightControlDataRecord> syncBase;
    WeightControlDataRecord oneLowLayerRecord;
    syncBase.clear();
    float minY = 10000.0, maxY = 0.0, tmpWeight;
    for(NSDictionary *oneRecord in delegateWeight.weightData){
        oneLowLayerRecord.timeInterval = [[oneRecord objectForKey:@"date"] timeIntervalSince1970];
        oneLowLayerRecord.weight = [[oneRecord objectForKey:@"weight"] floatValue];
        oneLowLayerRecord.trend = [[oneRecord objectForKey:@"trend"] floatValue];
        tmpWeight = MIN(oneLowLayerRecord.weight, oneLowLayerRecord.trend);
        if(tmpWeight<minY) minY = tmpWeight;
        tmpWeight = MAX(oneLowLayerRecord.weight, oneLowLayerRecord.trend);
        if(tmpWeight>maxY) maxY = tmpWeight;
        
        syncBase.push_back(oneLowLayerRecord);
    }
    
    if([delegateWeight.weightData count]>0){
        NSDictionary *firstObj, *lastObj;
        firstObj = [delegateWeight.weightData objectAtIndex:0];
        lastObj = [delegateWeight.weightData lastObject];
        
        RENDERER_TYPECAST(myRender)->SetXAxisParams([[firstObj objectForKey:@"date"] timeIntervalSince1970], [[lastObj objectForKey:@"date"] timeIntervalSince1970]);
        
        //RENDERER_TYPECAST(myRender)->SetYAxisParams(minY, maxY, 0.5);
    }
    
    RENDERER_TYPECAST(myRender)->SetDataBase(syncBase);
    RENDERER_TYPECAST(myRender)->UpdateYAxisParams();
    
};

#pragma martk - Handling gestures

- (void)handlePanGestureRecognizer:(UIPanGestureRecognizer *)gestureRecognizer{
    CGFloat offsetX = ((CGPoint)[gestureRecognizer translationInView:self]).x;
    CGFloat velocityXScroll = ((CGPoint)[gestureRecognizer velocityInView:self]).x;
    //NSLog(@"handlePanGestureRecognizer: translate = %.0f, velocity = %.0f", offsetX, velocityXScroll);
    if(gestureRecognizer.state==UIGestureRecognizerStateBegan){
        startPanOffset = RENDERER_TYPECAST(myRender)->getCurOffsetX() / RENDERER_TYPECAST(myRender)->getTimeIntervalPerPixel();
        curPanOffset = 0.0;
    };
    
    if(gestureRecognizer.state==UIGestureRecognizerStateChanged){
        //NSLog(@"current x-offset (in px) = %.2f",startPanOffset - offsetX);
        float trashOffset = startPanOffset - offsetX;
        float maxOffset = RENDERER_TYPECAST(myRender)->getMaxOffsetPx();
        if(trashOffset <=0){
            //NSLog(@"Offset: %.2f, Trash offset: %.2f, exp = %.2f, sqrt = %.2f", offsetX, trashOffset, expf(trashOffset), sqrtf(fabs(trashOffset)));
            offsetX = sqrtf(fabs(4*trashOffset));
        };
        if(trashOffset > maxOffset){
            offsetX = startPanOffset - maxOffset - sqrt(4*(trashOffset - maxOffset));
            //curPanOffset = startPanOffset - maxOffset;
            //return;
        }
        
        RENDERER_TYPECAST(myRender)->isPlotOutOfBoundsForOffsetAndScale(startPanOffset - offsetX, RENDERER_TYPECAST(myRender)->getCurScaleX());
        
        RENDERER_TYPECAST(myRender)->SetOffsetPixels(startPanOffset - offsetX, fabs((offsetX-curPanOffset) / velocityXScroll));
        RENDERER_TYPECAST(myRender)->UpdateYAxisParamsForOffsetAndScale(startPanOffset - offsetX, RENDERER_TYPECAST(myRender)->getCurScaleX(), fabs((offsetX-curPanOffset) / velocityXScroll));
        curPanOffset = offsetX;
        panTimestamp = CACurrentMediaTime();
        
    };
    
    if(gestureRecognizer.state==UIGestureRecognizerStateEnded){
        //RENDERER_TYPECAST(myRender)->SmoothPanFinish(velocityXScroll);
        float endDuration = (CACurrentMediaTime() - panTimestamp);
        float slideSize = (endDuration <= 0.5) ? velocityXScroll : 0.0;
        //NSLog(@"Pan velocity = %.2f timestamp = %.5f, slideSize = %.3f", velocityXScroll, endDuration, slideSize);
        
        float maxOffset = RENDERER_TYPECAST(myRender)->getMaxOffsetPx();
        if(startPanOffset - curPanOffset - slideSize <=0){
            slideSize = startPanOffset - curPanOffset;
            
            //NSLog(@"[left] startPanOffset = %.0f, slideSize = %.2f [left] ", slideSize);
        }else if(startPanOffset - curPanOffset - slideSize >= maxOffset){
            slideSize = startPanOffset - curPanOffset - maxOffset;
            //NSLog(@"slideSize = %.2f [right]", slideSize);
        };
        RENDERER_TYPECAST(myRender)->SetOffsetPixelsDecelerating(startPanOffset - curPanOffset - slideSize, 0.5);
        RENDERER_TYPECAST(myRender)->UpdateYAxisParamsForOffsetAndScale(startPanOffset - curPanOffset - slideSize, RENDERER_TYPECAST(myRender)->getCurScaleX(), 0.5);
        
        //NSLog(@"Finish scroll velocity: %.2f", fabs((offsetX-curPanOffset) / velocityXScroll));
    };
};

- (void)handlePinchGestureRecognizer:(UIPinchGestureRecognizer *)gestureRecognizer{
    CGFloat scale = gestureRecognizer.scale;
    CGFloat velocity = gestureRecognizer.velocity;
    //NSLog(@"handlePinchGestureRecognizer: scale = %.1f, velocity = %.1f", scale, velocity);
    if(gestureRecognizer.state==UIGestureRecognizerStateBegan){
        startScale = RENDERER_TYPECAST(myRender)->getCurScaleX();
        curScale = 1.0;
    };
    
    if(gestureRecognizer.state==UIGestureRecognizerStateChanged){
        float newXOffset = RENDERER_TYPECAST(myRender)->getCurOffsetXForScale(startScale*scale) / RENDERER_TYPECAST(myRender)->getTimeIntervalPerPixelForScale(startScale * scale);
        float offsetCorrect = 0.0;
        if(RENDERER_TYPECAST(myRender)->isPlotOutOfBoundsForOffsetAndScale(newXOffset, startScale*scale)==true){
            offsetCorrect = fabs((RENDERER_TYPECAST(myRender)->getPlotWidthPxForScale(startScale*scale) -
                             RENDERER_TYPECAST(myRender)->getPlotWidthPxForScale(startScale*curScale)) / 2.0);
            //offsetCorrect *= scale;
            if(newXOffset<=0){
                //offsetCorrect = 5.0;
            }else{
                offsetCorrect *= -1.0;
            };
            newXOffset += offsetCorrect;
            if(RENDERER_TYPECAST(myRender)->isPlotOutOfBoundsForOffsetAndScale(newXOffset, startScale*scale)==true){
                gestureRecognizer.scale = curScale;
                return;
            }
            
            NSLog(@"Plot width: %.2f -> %.2f", RENDERER_TYPECAST(myRender)->getPlotWidthPxForScale(startScale*curScale), RENDERER_TYPECAST(myRender)->getPlotWidthPxForScale(startScale*scale));
            //NSLog(@"offset correction for scale %.2f (last scale %.2f, scaleChange %.2f): %.2f", startScale*scale, startScale*curScale, startScale*(scale - curScale), offsetCorrect);
            float curOffsetX = RENDERER_TYPECAST(myRender)->getCurOffsetX() / RENDERER_TYPECAST(myRender)->getTimeIntervalPerPixelForScale(startScale*scale);
            RENDERER_TYPECAST(myRender)->SetOffsetPixels(curOffsetX + offsetCorrect, fabs((scale - curScale) / velocity));
        };
        
        RENDERER_TYPECAST(myRender)->UpdateYAxisParamsForOffsetAndScale(newXOffset, startScale * scale, fabs((scale - curScale) / velocity));
        RENDERER_TYPECAST(myRender)->SetScaleX(startScale * scale, fabs((scale - curScale) / velocity));
        
        curScale = scale;
    };
    
    
    
    //NSTimeInterval curXOffset = RENDERER_TYPECAST(myRender)->getCurOffsetX();
    //RENDERER_TYPECAST(myRender)->SetOffsetTimeInterval(curXOffset, true);
    
};

- (void)_testHorizontalLinesAnimating{
    if(tmpVal){
        RENDERER_TYPECAST(myRender)->SetYAxisParams(70.0, 80.0, 0.5, 1.0);
        //RENDERER_TYPECAST(myRender)->SetScaleX(4.0, true);
        RENDERER_TYPECAST(myRender)->SetOffsetTimeInterval(0.0, 1.0);
        
    }else{
        RENDERER_TYPECAST(myRender)->SetYAxisParams(70.0, 100.0, 0.5, 1.0);
        //RENDERER_TYPECAST(myRender)->SetScaleX(1.0, true);
        RENDERER_TYPECAST(myRender)->SetOffsetTimeInterval(60*60*24*3, 1.0);
    };
    tmpVal = !tmpVal;
}

@end
