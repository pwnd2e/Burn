//
//  KWDRFolder.m
//  Burn
//
//  Created by Maarten Foukhar on 28-4-07.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import "KWDRFolder.h"

@implementation KWDRFolder

- (id) init
{
    self = [super init];
    expanded = NO;
    filePackage = NO;
    hfsStandard = NO;

    return self;
}

- (void)setFolderIcon:(NSImage *)image
{
    if (folderIcon)
    {
	    folderIcon = nil;
    }

    if (image) 
    {
	    folderIcon = [image copy];
    }
}

- (NSImage *)folderIcon
{
    return folderIcon ? folderIcon : [[NSWorkspace sharedWorkspace] iconForFile:@"/bin"];
}

- (void)setFolderSize:(NSString *)string
{
    if (folderSize)
    {
	    folderSize = nil;
    }
    
    folderSize = [string copy];
}

- (NSString *)folderSize
{
    return folderSize;
}

- (void)setDiscProperties:(NSDictionary *)dict
{
    if (properties)
    {
	    properties = nil;
    }

    if (dict)
	    properties = [dict copy];
}

- (NSDictionary *)discProperties
{
    return properties;
}

- (void)setExpanded:(BOOL)exp
{
    expanded = exp;
}

- (BOOL)isExpanded
{
    return expanded;
}

- (void)setIsFilePackage:(BOOL)package
{
    filePackage = package;
}

- (BOOL)isFilePackage
{
    return filePackage;
}

- (void)setDisplayName:(NSString *)string
{
    if (displayName)
    {
	    displayName = nil;
    }
    
    displayName = [string copy];
}

- (NSString *)displayName
{
    return displayName;
}

- (void)setOriginalName:(NSString *)string
{
     if (originalName)
    {
	    originalName = nil;
    }
    
    originalName = [string copy];
}
 
- (NSString *)originalName
{
    return originalName;
}

- (void)setHfsStandard:(BOOL)standard
{
    hfsStandard = standard;
}

- (BOOL)hfsStandard
{
    return hfsStandard;
}

@end
