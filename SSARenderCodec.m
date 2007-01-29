//
//  SSARenderCodec.m
//  Perian
//
//  Created by Alexander Strange on 1/28/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "SSARenderCodec.h"
#import "SSADocument.h"
#import "SSATagParsing.h"

typedef struct SSARenderGlobals
{
	SSADocument *document;
} SSARenderGlobals;

SSARenderGlobalsPtr SSA_Init(const char *header, size_t size)
{
	SSARenderGlobalsPtr g = (SSARenderGlobalsPtr)NewPtr(sizeof(SSARenderGlobals));
	NSString *hdr = [[NSString alloc] initWithBytesNoCopy:(void*)header length:size encoding:NSUTF8StringEncoding freeWhenDone:NO];
	g->document = [[SSADocument alloc] init];
	[g->document loadHeader:hdr];
	[hdr release];
	return g;
}

static NSPoint np(FixedPoint fp)
{
	float x = FixedToFloat(fp.x), y = (480. - FixedToFloat(fp.y));
	return NSMakePoint(x,y);
}

static void GetTypographicRectangleForLayout(SSARenderEntity *re, UniCharArrayOffset *breaks, ItemCount breakCount, Fixed *height, Fixed *width, unsigned baseX, unsigned baseY, float iheight)
{
	ATSTrapezoid trap = {0};
	ItemCount trapCount;
	FixedRect largeRect = {0};
	ATSUTextMeasurement ascent, descent;
	
	int i;
	for (i = breakCount; i >= 0; i--) {		
		UniCharArrayOffset end = breaks[i+1];
		FixedRect rect;
		OSStatus err;
		
		//[[NSColor redColor] set];
		//NSBezierPath *path = [NSBezierPath bezierPath];
		err=ATSUGetGlyphBounds(re->layout,baseX,FloatToFixed(iheight) - baseY,breaks[i],end-breaks[i],kATSUseDeviceOrigins,1,&trap,&trapCount);
		
		ATSUGetLineControl(re->layout, breaks[i], kATSULineAscentTag, sizeof(ATSUTextMeasurement), &ascent, NULL);
		ATSUGetLineControl(re->layout, breaks[i], kATSULineDescentTag, sizeof(ATSUTextMeasurement), &descent, NULL);
		
		baseY += ascent + descent;
		/*	
			[path moveToPoint:np(trap.lowerLeft)];
		 [path lineToPoint:np(trap.lowerRight)];
		 [path lineToPoint:np(trap.upperRight)];
		 [path lineToPoint:np(trap.upperLeft)];
		 [path closePath];
		 [path stroke];
		 */
		rect.bottom = MAX(trap.lowerLeft.y, trap.lowerRight.y);
		rect.left = MIN(trap.lowerLeft.x, trap.upperLeft.x);
		rect.top = MIN(trap.upperLeft.y, trap.upperRight.y);
		rect.right = MAX(trap.lowerRight.x, trap.upperRight.x);
		
		if (i == breakCount) largeRect = rect;
		
		largeRect.bottom = MAX(largeRect.bottom, rect.bottom);
		largeRect.left = MIN(largeRect.left, rect.left);
		largeRect.top = MIN(largeRect.top, rect.top);
		largeRect.right = MAX(largeRect.right, rect.right);
	}
	*height = largeRect.bottom - largeRect.top;
	*width = largeRect.right - largeRect.left;
}

void SSA_RenderLine(SSARenderGlobalsPtr glob, CGContextRef c, const char *data, size_t size, float cWidth, float cHeight)
{
	ItemCount breakCount;
	Fixed penY,penX;
	Fixed lastTopPenY=-1, lastBottomPenY=-1, lastCenterPenY=-1, *storePenY, ignoredPenY;
	int i, lstart, lend, lstep, subcount, j; char direction;
	float outline, shadow;
	SSADocument *ssa = glob->document;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSString *curSub = [[NSString alloc] initWithBytesNoCopy:(void*)data length:size encoding:NSUTF8StringEncoding freeWhenDone:NO];
	NSArray *rentities = ParseSubPacket(curSub,ssa);
	OSStatus err;
	
	CGContextScaleCTM(c, cWidth / ssa->resX, cHeight / ssa->resY);
	subcount = [rentities count];
	
	for (j = 0; j < subcount; j++) {
		SSARenderEntity *re = (SSARenderEntity*)[rentities objectAtIndex:j];
		ATSUTextLayout layout = re->layout;
		
		outline = re->styles[0]->outline; shadow = re->styles[0]->shadow;
		
		size_t sublen = [re->nstext length];
				
		err=ATSUSetTextPointerLocation(layout,re->text,kATSUFromTextBeginning,kATSUToTextEnd,sublen);
		
		ATSUSetTransientFontMatching(layout,TRUE);
		
		for (i = 0; i < re->style_count; i++) ATSUSetRunStyle(layout,re->styles[i]->astyle,re->styles[i]->range.location,re->styles[i]->range.length);
		
		{
			ATSUAttributeTag ct[] = {kATSUCGContextTag};
			ByteCount		 cs[] = {sizeof(CGContextRef)};
			ATSUAttributeValuePtr cv[] = {&c};
			
			ATSUSetLayoutControls(layout,1,ct,cs,cv);
		}
		
		ATSUBatchBreakLines(layout,kATSUFromTextBeginning,kATSUToTextEnd,IntToFixed(re->usablewidth),&breakCount); 
		ATSUGetSoftLineBreaks(layout,kATSUFromTextBeginning,kATSUToTextEnd,0,NULL,&breakCount);
		UniCharArrayOffset breaks[breakCount+2];
		ATSUGetSoftLineBreaks(layout,kATSUFromTextBeginning,kATSUToTextEnd,breakCount,&breaks[1],&breakCount);
		
		breaks[0] = 0;
		breaks[breakCount+1] = sublen;
		
		penX = IntToFixed(re->marginl);
		
		if (re->posx == -1) {
			ATSUTextMeasurement ascent, descent, total = 0;
			
			switch (re->valign)
			{
				case S_BottomAlign: default: //bottom
					ATSUGetLineControl(layout, kATSUFromTextBeginning, kATSULineDescentTag, sizeof(ATSUTextMeasurement), &descent, NULL);
					penY = (lastBottomPenY!=-1)?lastBottomPenY:(MAX(IntToFixed(re->marginv), descent)); direction = 1;
					lstart = breakCount; lend = -1; lstep = -1;
					storePenY = &lastBottomPenY;
					break;
				case S_MiddleAlign: // center
					penY = (lastCenterPenY!=-1)?lastCenterPenY:(FloatToFixed((cHeight - FixedToFloat(total)) / 2.));  direction = -1;
					lstart = 0; lend = breakCount+1; lstep = 1;
					storePenY = &lastCenterPenY;
					break;
				case S_TopAlign: //top
					ATSUGetLineControl(layout, kATSUFromTextBeginning, kATSULineAscentTag, sizeof(ATSUTextMeasurement), &ascent, NULL); // pen has to be positioned below the first line
					ATSUGetLineControl(layout, kATSUFromTextBeginning, kATSULineDescentTag, sizeof(ATSUTextMeasurement), &descent, NULL);
					
					penY = (lastTopPenY!=-1)?lastTopPenY:(FloatToFixed(cHeight - re->marginv) - ascent - descent); direction = -1;
					lstart = 0; lend = breakCount+1; lstep = 1;
					storePenY = &lastTopPenY;
					break;
			}
		}
		else {
			Fixed imageHeight, imageWidth;
			
			GetTypographicRectangleForLayout(re,breaks,breakCount,&imageHeight,&imageWidth,penX,penY,ssa->resY);
			
			storePenY = &ignoredPenY;
			penX = IntToFixed(re->posx);
			penY = FloatToFixed((ssa->resY - re->posy));
			/*			
				NSBezierPath *posPath = [NSBezierPath bezierPath];
			[[NSColor redColor] set];
			[posPath setLineWidth:2.5];
			[posPath moveToPoint:NSMakePoint(re->posx,0)];
			[posPath lineToPoint:NSMakePoint(re->posx,ssa->resY)];
			[posPath moveToPoint:NSMakePoint(0,re->posy)];
			[posPath lineToPoint:NSMakePoint(ssa->resX,re->posy)];
			[posPath closePath];
			[posPath stroke];
			*/
			switch(re->halign) {
				case S_CenterAlign:
					penX -= imageWidth / 2;
					break;
				case S_RightAlign:
					penX -= imageWidth;
			}
			
			switch(re->valign) {
				case S_MiddleAlign:
					penY -= imageHeight / 2;
					break;
				case S_RightAlign:
					penY -= imageHeight;
			}
			
			direction = 1;
			lstart = breakCount; lend = -1; lstep = -1;
		}
		
		CGContextSetLineJoin(c, kCGLineJoinRound);
		CGContextSetLineCap(c, kCGLineCapRound);
		CGContextSetLineWidth(c,outline * 2.);
		CGContextSetTextDrawingMode(c, kCGTextFillStroke);	
		
		if (shadow > 0) {
			if (outline == 0) outline = 1;
			
			CGContextSetRGBFillColor(c,re->styles[0]->color.shadow.red,re->styles[0]->color.shadow.green,re->styles[0]->color.shadow.blue,re->styles[0]->color.shadow.alpha);
			CGContextSetRGBStrokeColor(c,re->styles[0]->color.shadow.red,re->styles[0]->color.shadow.green,re->styles[0]->color.shadow.blue,re->styles[0]->color.shadow.alpha);
			
			Fixed shadowX = FloatToFixed(re->styles[0]->shadow) + penX, oldY = penY;
			penY -= FloatToFixed(re->styles[0]->shadow);
			
			for (i = lstart; i != lend; i += lstep) {
				int end = breaks[i+1];
				
				ATSUDrawText(layout,breaks[i],end-breaks[i],shadowX,penY);
				
				ATSUTextMeasurement ascent, descent;
				ATSUGetLineControl(layout, breaks[i], kATSULineAscentTag, sizeof(ATSUTextMeasurement), &ascent, NULL);
				ATSUGetLineControl(layout, breaks[i], kATSULineDescentTag, sizeof(ATSUTextMeasurement), &descent, NULL);
				
				penY += direction * (ascent + descent);
			}
			
			penY = oldY;
		}
		
		CGContextSetRGBFillColor(c,re->styles[0]->color.primary.red,re->styles[0]->color.primary.green,re->styles[0]->color.primary.blue,re->styles[0]->color.primary.alpha);
		CGContextSetRGBStrokeColor(c,re->styles[0]->color.outline.red,re->styles[0]->color.outline.green,re->styles[0]->color.outline.blue,re->styles[0]->color.outline.alpha);
		
		for (i = lstart; i != lend; i += lstep) {
			int end = breaks[i+1];
			
			if (outline > 0) {
				CGContextSetTextDrawingMode(c, kCGTextStroke);
				
				ATSUDrawText(layout,breaks[i],end-breaks[i],penX,penY);
				
				CGContextSetTextDrawingMode(c, kCGTextFill);			
			}
			
			err=ATSUDrawText(layout,breaks[i],end-breaks[i],penX,penY);
			
			ATSUTextMeasurement ascent, descent;
			ATSUGetLineControl(layout, breaks[i], kATSULineAscentTag, sizeof(ATSUTextMeasurement), &ascent, NULL);
			ATSUGetLineControl(layout, breaks[i], kATSULineDescentTag, sizeof(ATSUTextMeasurement), &descent, NULL);
			
			penY += direction * (ascent + descent);
		}
		
		*storePenY = penY;
	}
	
	[curSub release];
	[pool release];
	CGContextSynchronize(c);	
	CGContextRelease(c);
}

void SSA_Dispose(SSARenderGlobalsPtr glob)
{
	[glob->document release];
	DisposePtr((Ptr)glob);
}