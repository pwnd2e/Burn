#import <Cocoa/Cocoa.h>
#import "KWCommonMethods.h"

@interface KWConverter : NSObject
{
    //ffmpeg the main encoder
    NSTask *ffmpeg;
    //Status: 0=idle, 1=encoding audio, 2=encoding video
    NSInteger status;
    //Number of file encoding
    NSInteger number;
    //aspect ratio for current movie
    NSInteger aspectValue;
    //Last encoded file
    NSString *encodedOutputFile;
    //Needed for the one who speaks to the class
    NSMutableArray *convertedFiles;
    //To differ if it must be reported to be a problem (when canceling)
    BOOL userCanceled;
    
    //Input file values
    NSInteger inputWidth;
    NSInteger inputHeight;
    float inputFps;
    NSInteger inputTotalTime;
    float inputAspect;
    //inputFormat: 0 = normal; 1 = dv; 2 = mpeg2
    NSInteger inputFormat;

    NSDictionary *convertOptions;
    NSString *errorString;
    NSString *convertDestination;
    NSString *convertExtension;
    NSInteger convertRegion;
    NSInteger convertKind;
    
    BOOL copyAudio;
}

//Encode actions

//Convert a bunch of files with ffmpeg/movtoyuv/QuickTime
- (NSInteger)batchConvert:(NSArray *)files withOptions:(NSDictionary *)options errorString:(NSString **)error;
//Encode the file
- (NSInteger)encodeFileAtPath:(NSString *)path;
//Stop encoding (stop ffmpeg)
- (void)cancelEncoding;

//Test actions

//Test if ffmpeg can encode, sound and/or video, and if it does have any sound
- (NSInteger)testFile:(NSString *)path;
//Test methods used in (NSInteger)testFile....
- (BOOL)streamWorksOfKind:(NSString *)kind inOutput:(NSString *)output;
- (BOOL)isReferenceMovie:(NSString *)output;
- (BOOL)setTimeAndAspectFromOutputString:(NSString *)output fromFile:(NSString *)file;

//Compilant actions
//Generic command to get info on the input file
+ (NSString *)ffmpegOutputForPath:(NSString *)path;
//Check if the file is a valid VCD file (return YES if it is valid)
- (BOOL)isVCD:(NSString *)path;
//Check if the file is a valid SVCD file (return YES if it is valid)
- (BOOL)isSVCD:(NSString *)path;
//Check if the file is a valid DVD file (return YES if it is valid)
- (BOOL)isDVD:(NSString *)path isWideAspect:(BOOL *)wideAspect;
//Check if the file is a valid MPEG4 file (return YES if it is valid)
- (BOOL)isMPEG4:(NSString *)path;
//Check for ac3 audio
- (BOOL)containsAC3:(NSString *)path;

//Framework actions
- (NSArray *)succesArray;

//Other actions
- (NSInteger)convertToEven:(NSString *)number;
- (NSInteger)getPadSize:(float)size withAspect:(NSSize)aspect withTopBars:(BOOL)topBars;
- (BOOL)remuxMPEG2File:(NSString *)path outPath:(NSString *)outFile;
- (BOOL)canCombineStreams:(NSString *)path;
- (BOOL)combineStreams:(NSString *)path atOutputPath:(NSString *)outputPath;
- (NSInteger)totalTimeInSeconds:(NSString *)path;
+ (NSString *)totalTimeString:(NSString *)path;
- (NSString *)mediaTimeString:(NSString *)path;
- (NSImage *)getImageAtPath:(NSString *)path atTime:(NSInteger)time isWideScreen:(BOOL)wide;
- (void)setErrorStringWithString:(NSString *)string;

@end
