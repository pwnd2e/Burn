#import "KWAudioMP3Inspector.h"
#import "KWAudioController.h"
#import "MultiTag/MultiTag.h"

@implementation KWAudioMP3Inspector

- (id)init
{
    if (self = [super init])
    {
	    methodMappings = [[NSArray alloc] initWithObjects:    //NSStrings
    	    	    	    	    	    	    	    @"TagTitle",	    	    //1
    	    	    	    	    	    	    	    @"TagArtist",	    	    //2
    	    	    	    	    	    	    	    @"TagComposer",	    	    //3
    	    	    	    	    	    	    	    @"TagAlbum",	    	    //4
    	    	    	    	    	    	    	    @"TagComments",	    	    //5
    	    	    	    	    	    	    	    //ints
    	    	    	    	    	    	    	    @"TagYear",    	    	    //6
    	    	    	    	    	    	    	    @"TagTrack",	    	    //7
    	    	    	    	    	    	    	    @"TagTotalNumberTracks",    //8
    	    	    	    	    	    	    	    @"TagDisk",    	    	    //9
    	    	    	    	    	    	    	    @"TagTotalNumberDisks",	    //10
    	    	    	    	    	    	    	    //NSArray
    	    	    	    	    	    	    	    @"TagGenreNames",    	    //11
	    nil];
	    
	    currentIndex = 0;
    }

    return self;
}

- (void)updateView:(id)object
{
    currentTableView = object;
    KWAudioController *controller = (KWAudioController *)[currentTableView delegate];
    NSArray *tableData = [controller myDataSource];
    NSArray *currentObjects = [KWCommonMethods allSelectedItemsInTableView:currentTableView fromArray:tableData];

    if ([currentObjects count] == 1)
    {
	    [iconView setImage:[[currentObjects objectAtIndex:0] objectForKey:@"Icon"]];
	    [nameField setStringValue:[[currentObjects objectAtIndex:0] objectForKey:@"Name"]];
	    [sizeField setStringValue:[[currentObjects objectAtIndex:0] objectForKey:@"Size"]];
	    
    }
    else
    {
	    [iconView setImage:[NSImage imageNamed:@"Multiple"]];
	    [nameField setStringValue:@"Multiple Selection"];
	    [sizeField setStringValue:[NSString localizedStringWithFormat:@"%ld files",[currentObjects count]]];
    }

    NSView *firstTabViewItem = [[tabView tabViewItemAtIndex:0] view];
    NSEnumerator *iter = [[firstTabViewItem subviews] objectEnumerator];
    id cntl;

    while ((cntl = [iter nextObject]) != NULL)
    {
	    NSInteger index = [cntl tag] - 1;
	    
	    if (index > -1 && index < 11)
	    {    
    	    id currentMethod = [methodMappings objectAtIndex:index];
    	    NSString *methodString = [NSString stringWithFormat:@"get%@", currentMethod];
    	    SEL method = NSSelectorFromString(methodString);
    	    id property = [self getObjectWithSelector:method fromObjects:currentObjects];
    	    
    	    if ([property isKindOfClass:[NSArray class]])
    	    {
	    	    NSString *genreList = [property objectAtIndex:0];
    	    
	    	    NSInteger i;
	    	    for (i=1;i<[property count];i++)
	    	    {
    	    	    NSString *newGenre = [property objectAtIndex:i];
    	    	    genreList = [NSString stringWithFormat:@"%@, %@", genreList, newGenre];
	    	    }
	    	    
	    	    [cntl setObjectValue:genreList];
    	    }
    	    else 
    	    {
	    	    if (property)
    	    	    [cntl setObjectValue:property];
    	    }
	    }
    }
	    
    [self updateArtWork];
}

- (id)getObjectWithSelector:(SEL)selector fromObjects:(NSArray *)objects
{
    NSString *path = [[objects objectAtIndex:0] objectForKey:@"Path"];
    MultiTag *soundTag = [[MultiTag alloc] initWithFile:path];
    
    // TODO: just write things out, since it's saver for ARC and us :)
    id baseValue = [soundTag performSelector:selector];

    if ([objects count] == 1)
    {
	    if (selector == @selector(getYear))
    	    return [NSNumber numberWithInt:[baseValue intValue]];
	    else if ([baseValue isKindOfClass:[NSNumber class]] && [baseValue intValue] == -1)
    	    return @"";
	    else
    	    return baseValue;
    }
    else 
    {
	    NSInteger i;
	    for (i=0;i<[objects count];i++)
	    {
    	    path = [[objects objectAtIndex:i] objectForKey:@"Path"];
    	    soundTag = [[MultiTag alloc] initWithFile:path];
    	    
    	    id currentValue = [soundTag performSelector:selector];
    	    
	    	    if (![currentValue isEqualTo:baseValue])
	    	    {
    	    	    if ([baseValue isKindOfClass:[NSString class]])
	    	    	    return @"";
    	    	    else
	    	    	    return nil;
	    	    }
	    }
    }
    
	    if ([baseValue isKindOfClass:[NSNumber class]] && [baseValue intValue] == -1)
    	    return @"";
	    else
    	    return baseValue;
}

- (void)setObjectWithSelector:(SEL)selector forObjects:(NSArray *)objects withObject:(id)object
{
    NSInteger i;
    for (i=0;i<[objects count];i++)
    {
	    id finalObject = object;
	    NSString *method = NSStringFromSelector(selector);
	    
	    if ([method isEqualTo:@"setTagGenreNames:"])
    	    finalObject = [object componentsSeparatedByString:@", "];
    
	    NSString *path = [[objects objectAtIndex:i] objectForKey:@"Path"];
	    MultiTag *soundTag = [[MultiTag alloc] initWithFile:path];
        // TODO: just write things out, since it's saver for ARC and us :)
	    [soundTag performSelector:selector withObject:finalObject];
	    [soundTag updateFile];
    }
}

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    if ([[tabViewItem label] isEqualTo:@"Artwork"])
    {
	    [self updateArtWork];
    }
}

- (void)updateArtWork
{
    KWAudioController *controller = (KWAudioController *)[currentTableView delegate];
    NSArray *tableData = [controller myDataSource];
    NSArray *currentObjects = [KWCommonMethods allSelectedItemsInTableView:currentTableView fromArray:tableData];

    NSArray *images = [self getObjectWithSelector:@selector(getTagImage) fromObjects:currentObjects];
    
    if (currentIndex > [images count] - 1)
	    currentIndex = 0;
	    
    if (images && [images count] > 0)
    {
	    NSImage *Image1 = [[NSImage alloc] init];
	    [Image1 addRepresentation:[[images objectAtIndex:currentIndex] objectForKey:@"Image"]];
	    [imageView setImage:Image1];
	    
	    NSString *countString = [NSString stringWithFormat:@"%ld of %ld", currentIndex + 1, [images count]];
	    [imageString setStringValue:countString];
    }
    else
    {
	    [imageView setImage:nil];
	    NSString *countString = [NSString stringWithFormat:@"%ld of %ld",(long)0,(long)0];
	    [imageString setStringValue:countString];
    }
}

- (IBAction)addImage:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    
    [openPanel setCanChooseDirectories:NO];
    [openPanel setCanChooseFiles:YES];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setResolvesAliases:YES];
    [openPanel setAllowedFileTypes:[NSImage imageFileTypes]];
    [openPanel beginSheetModalForWindow:[myView window] completionHandler:^(NSModalResponse result)
    {
        if (result == NSModalResponseOK)
        {
            KWAudioController *controller = (KWAudioController *)[currentTableView delegate];
            NSArray *tableData = [controller myDataSource];
            NSArray *currentObjects = [KWCommonMethods allSelectedItemsInTableView:currentTableView fromArray:tableData];
        
            NSMutableArray *pictures = [self getObjectWithSelector:@selector(getTagImage) fromObjects:currentObjects];
        
            if ([pictures count] == 0)
            {
                pictures = [[NSMutableArray alloc] init];
            }

            for (NSURL *url in [openPanel URLs])
            {
                NSMutableDictionary *image = [NSMutableDictionary dictionaryWithCapacity:4];
            
                [image setObject:[[NSBitmapImageRep imageRepsWithData:[NSData dataWithContentsOfFile:[url path]]] objectAtIndex:0] forKey:@"Image"];
                [image setObject:@"Other" forKey:@"Picture Type"];
                [image setObject:[NSString stringWithFormat:@"image/%@", [url pathExtension]] forKey:@"Mime Type"];
                [image setObject:@"" forKey:@"Description"];
                
                if ([currentObjects count] == 1)
                {
                    [pictures insertObject:image atIndex:currentIndex + 1];
                    currentIndex = currentIndex + 1;
                }
                else
                {
                    [pictures addObject:image];
                }
            }
        
            [self setObjectWithSelector:@selector(setTagImages:) forObjects:currentObjects withObject:pictures];
            
            [self updateArtWork];
        }
    }];
}

- (IBAction)nextImage:(id)sender
{
    currentIndex = currentIndex + 1;
    [self updateArtWork];
}

- (IBAction)optionsChanged:(id)sender
{
    KWAudioController *controller = (KWAudioController *)[currentTableView delegate];
    NSArray *tableData = [controller myDataSource];
    NSArray *currentObjects = [KWCommonMethods allSelectedItemsInTableView:currentTableView fromArray:tableData];
    
    NSInteger index = [sender tag] - 1;
    id currentMethod = [methodMappings objectAtIndex:index];
    NSString *methodString = [NSString stringWithFormat:@"set%@:", currentMethod];
    SEL method = NSSelectorFromString(methodString);

    [self setObjectWithSelector:method forObjects:currentObjects withObject:[sender objectValue]];
}

- (IBAction)previousImage:(id)sender
{
    currentIndex = currentIndex - 1;
    [self updateArtWork];
}

- (IBAction)removeImage:(id)sender
{
    KWAudioController *controller = (KWAudioController *)[currentTableView delegate];
    NSArray *tableData = [controller myDataSource];
    NSArray *currentObjects = [KWCommonMethods allSelectedItemsInTableView:currentTableView fromArray:tableData];

    NSMutableArray *images = [self getObjectWithSelector:@selector(getTagImage) fromObjects:currentObjects];
    
    if ([images count] > 1)
    {
	    [images removeObjectAtIndex:currentIndex];
	    [self setObjectWithSelector:@selector(setTagImages:) forObjects:currentObjects withObject:images];
	    
	    currentIndex = currentIndex - 1;
	    [self updateArtWork];
    }
}

- (id)myView
{
    return myView;
}

@end
