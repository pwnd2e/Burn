/*
     File:       ImageAndTextCell.m
 
     Contains:   Subclass of NSTextFieldCell which can display text and an image simultaneously.
 
     Version:    Technology: Mac OS X
                 Release:    Mac OS X
 
     Copyright:  (c) 2002 by Apple Computer, Inc., all rights reserved
 
     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:
 
                     https://developer.apple.com/bugreporter/
*/

/*
 IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc. ("Apple") in
 consideration of your agreement to the following terms, and your use, installation, 
 modification or redistribution of this Apple software constitutes acceptance of these 
 terms.  If you do not agree with these terms, please do not use, install, modify or 
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and subject to these 
 terms, Apple grants you a personal, non-exclusive license, under Apple‚Äôs copyrights in 
 this original Apple software (the "Apple Software"), to use, reproduce, modify and 
 redistribute the Apple Software, with or without modifications, in source and/or binary 
 forms; provided that if you redistribute the Apple Software in its entirety and without 
 modifications, you must retain this notice and the following text and disclaimers in all 
 such redistributions of the Apple Software.  Neither the name, trademarks, service marks 
 or logos of Apple Computer, Inc. may be used to endorse or promote products derived from 
 the Apple Software without specific prior written permission from Apple. Except as expressly
 stated in this notice, no other rights or licenses, express or implied, are granted by Apple
 herein, including but not limited to any patent rights that may be infringed by your 
 derivative works or by other works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO WARRANTIES, 
 EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, 
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS 
 USE AND OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR CONSEQUENTIAL 
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS 
 OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, 
 REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND 
 WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR 
 OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "ImageAndTextCell.h"
#import <DiscRecording/DiscRecording.h>
#import "KWDataController.h"
#import "KWDRFolder.h"

@implementation ImageAndTextCell

- (void)dealloc
{
    image = nil;
}

- copyWithZone:(NSZone *)zone 
{
    ImageAndTextCell *cell = (ImageAndTextCell *)[super copyWithZone:zone];
    cell->image = image;
    
    return cell;
}

- (void)setImage:(NSImage *)anImage 
{
    if (anImage != image) 
    {
	    image = anImage;
    }
}

- (NSImage *)image 
{
    return image;
}

- (NSRect)imageFrameForCellFrame:(NSRect)cellFrame 
{
    if (image != nil) 
    {
        NSRect imageFrame;
        imageFrame.size = [image size];
        imageFrame.origin = cellFrame.origin;
        imageFrame.origin.x += 3;
        imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);

        return imageFrame;
    }
    else
    {
        return NSZeroRect;
    }
}

- (void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent 
{    
    NSRect textFrame, imageFrame;
    NSDivideRect (aRect, &imageFrame, &textFrame, 3 + [image size].width, NSMinXEdge);
    [super editWithFrame: textFrame inView: controlView editor:textObj delegate:anObject event: theEvent];
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength
{
    NSRect textFrame, imageFrame;
    NSDivideRect (aRect, &imageFrame, &textFrame, 3 + 16, NSMinXEdge);
    

    KWDRFolder *folder = [[(KWDataController *)[anObject delegate] selectedDRFSObjects] objectAtIndex:0];    
    
    BOOL isDir;
    if (![folder isVirtual])
	    [[NSFileManager defaultManager] fileExistsAtPath:[folder sourcePath] isDirectory:&isDir];

    NSInteger newSelLength;
    if ([folder isVirtual] && ![folder isFilePackage])
	    newSelLength = ([[self stringValue] length]);
    else if (![folder isVirtual] && isDir && ![[NSWorkspace sharedWorkspace] isFilePackageAtPath:[folder sourcePath]])
	    newSelLength = ([[self stringValue] length]);
    else if (![[[self stringValue] pathExtension] isEqualTo:@""])
	    newSelLength = ([[self stringValue] length]) - ([[[self stringValue] pathExtension] length] + 1);
    else
	    newSelLength = ([[self stringValue] length]);

    [super selectWithFrame:textFrame inView:controlView editor:textObj delegate:anObject start:selStart length:newSelLength];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView 
{
    if (image != nil) 
    {
        NSSize    imageSize;
	    NSRect    imageFrame;
    
	    NSSize originalSize = [image size];
	    [image setSize:NSMakeSize(16,16)];

	    imageSize = [image size];
	    NSDivideRect(cellFrame, &imageFrame, &cellFrame, 3 + imageSize.width, NSMinXEdge);
        
	    if ([self drawsBackground]) 
	    {
    	    [[self backgroundColor] set];
    	    NSRectFill(imageFrame);
        }
	    
	    imageFrame.origin.x += 3;
	    imageFrame.size = imageSize;

        if ([controlView isFlipped])
    	    imageFrame.origin.y += ceil((cellFrame.size.height + imageFrame.size.height) / 2);
        else
    	    imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);
    
        // TODO: switch to a view based table view
        [image compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
        
	    [image setSize:originalSize];
    }
    
    [super drawWithFrame:cellFrame inView:controlView];
}

- (NSSize)cellSize 
{
    NSSize cellSize = [super cellSize];
    cellSize.width += (image ? [image size].width : 0) + 3;
    return cellSize;
}

@end
