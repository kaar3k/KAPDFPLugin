//
//  KAPDFPLugin.m
//  CreatePDF
//
//  Created by Karthik M on 23/05/13.
//
//

#import "KAPDFPLugin.h"
#import <QuartzCore/QuartzCore.h>

#define PDFWIDTH 612

@implementation KAPDFPLugin
@synthesize webViewHeight;
@synthesize imageName;

#pragma mark - Plugin Signature

- (void)generatePDF:(CDVInvokedUrlCommand*)command
{
    webViewHeight = [[self.webView stringByEvaluatingJavaScriptFromString:@"document.body.scrollHeight;"]
                     integerValue];

    [self.commandDelegate runInBackground:^{
       [self createPDFromCurrentWebView:^(NSString *filePath) {
           CDVPluginResult *result=[CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                     messageAsString:filePath];
           [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
           
       } failureBlock:^(BOOL status) {
           CDVPluginResult *result=[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
           [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
           
       }];
    }];
}


#pragma mark - PDF 

- (void)createPDFromCurrentWebView:(void(^)(NSString* filePath))succes
    failureBlock:(void(^)(BOOL status))failed
{
    
    CGRect screenRect = self.webView.frame;
    double currentWebViewHeight = webViewHeight;
    while (currentWebViewHeight > 0)
    {
        imageName ++;
        
        UIGraphicsBeginImageContext(screenRect.size);

        [self.webView.layer renderInContext:UIGraphicsGetCurrentContext()];
        UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
        
        NSString *pngPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%d.png",imageName]];
        
        CGFloat viewHeight=self.webView.frame.size.height;
        if(currentWebViewHeight < viewHeight)
        {
            CGRect lastImageRect = CGRectMake(0, viewHeight - currentWebViewHeight, self.webView.frame.size.width, currentWebViewHeight);
            CGImageRef imageRef = CGImageCreateWithImageInRect([newImage CGImage], lastImageRect);
            
            newImage = [UIImage imageWithCGImage:imageRef];
            CGImageRelease(imageRef);
        }
        
        NSError *error=nil;
        BOOL result=[UIImagePNGRepresentation(newImage)
                                writeToFile:pngPath
                            options:NSDataWritingAtomic error:&error];
        
        NSString *scrollJS=[NSString stringWithFormat:@"window.scrollBy(0,%f);",viewHeight];
        if (!result) {
            failed(result);
        }
        
        [self.webView performSelectorOnMainThread:@selector(stringByEvaluatingJavaScriptFromString:)
                                       withObject:scrollJS waitUntilDone:YES];
        currentWebViewHeight -= viewHeight;
    }
    
    succes([self drawPdf]);

}

- (NSString*) drawPdf
{
    CGSize pageSize = CGSizeMake(PDFWIDTH, webViewHeight);
    NSString *fileName = @"Demo.pdf";
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *pdfFileName = [documentsDirectory stringByAppendingPathComponent:fileName];
    UIGraphicsBeginPDFContextToFile(pdfFileName, CGRectZero, nil);
    
    // Mark the beginning of a new page.
    UIGraphicsBeginPDFPageWithInfo(CGRectMake(0, 0, pageSize.width, pageSize.height), nil);
    
    double currentHeight = 0.0;
    for (int index = 1; index  <= imageName ; index++)
    {
        NSString *pngPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%d.png", index]];
        UIImage *pngImage = [UIImage imageWithContentsOfFile:pngPath];
        
        [pngImage drawInRect:CGRectMake(0, currentHeight, pageSize.width, pngImage.size.height)];
        currentHeight += pngImage.size.height;
    }
    
    UIGraphicsEndPDFContext();
    
    return pdfFileName;
}

@end
