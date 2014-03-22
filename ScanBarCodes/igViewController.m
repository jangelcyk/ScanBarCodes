//
//  igViewController.m
//  ScanBarCodes
//
//  Created by Torrey Betts on 10/10/13.
//  Copyright (c) 2013 Infragistics. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "igViewController.h"


//#define WORK

#ifdef WORK
#  define WEBSERVERURL @"http://172.16.2.117/phpsqltest.php?bc="
#else
#  define WEBSERVERURL @"http://192.168.1.220/phpsqltest.php?bc="
#endif


@interface igViewController () <AVCaptureMetadataOutputObjectsDelegate>
{
    AVCaptureSession *_session;
    AVCaptureDevice *_device;
    AVCaptureDeviceInput *_input;
    AVCaptureMetadataOutput *_output;
    AVCaptureVideoPreviewLayer *_prevLayer;

    UIView *_highlightView;
    UILabel *_label;
    
    NSMutableString *lastDetectedString;
}
@end

@implementation igViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    _highlightView = [[UIView alloc] init];
    _highlightView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleBottomMargin;
    _highlightView.layer.borderColor = [UIColor greenColor].CGColor;
    _highlightView.layer.borderWidth = 3;
    [self.view addSubview:_highlightView];

    _label = [[UILabel alloc] init];
    _label.frame = CGRectMake(0, self.view.bounds.size.height - 400, self.view.bounds.size.width, 400);
    _label.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    _label.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.40];
    _label.textColor = [UIColor whiteColor];
    [_label setFont:[UIFont systemFontOfSize:10]];
    _label.textAlignment = NSTextAlignmentLeft;
    _label.lineBreakMode = TRUE;
    _label.numberOfLines = 30;
    _label.text = @"(none)";
    [self.view addSubview:_label];

    lastDetectedString = [[NSMutableString alloc] init];
    
    _session = [[AVCaptureSession alloc] init];
    _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;

    _input = [AVCaptureDeviceInput deviceInputWithDevice:_device error:&error];
    if (_input) {
        [_session addInput:_input];
    } else {
        NSLog(@"Error: %@", error);
    }

    _output = [[AVCaptureMetadataOutput alloc] init];
    [_output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    [_session addOutput:_output];

    _output.metadataObjectTypes = [_output availableMetadataObjectTypes];

    _prevLayer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
    _prevLayer.frame = self.view.bounds;
    _prevLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer:_prevLayer];

    [_session startRunning];

    [self.view bringSubviewToFront:_highlightView];
    [self.view bringSubviewToFront:_label];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [_session startRunning];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    CGRect highlightViewRect = CGRectZero;
    AVMetadataMachineReadableCodeObject *barCodeObject;
    NSString *detectionString = nil;
    NSArray *barCodeTypes = @[AVMetadataObjectTypeUPCECode, AVMetadataObjectTypeCode39Code, AVMetadataObjectTypeCode39Mod43Code,
            AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode93Code, AVMetadataObjectTypeCode128Code,
            AVMetadataObjectTypePDF417Code, AVMetadataObjectTypeQRCode, AVMetadataObjectTypeAztecCode];

    for (AVMetadataObject *metadata in metadataObjects) {
        for (NSString *type in barCodeTypes) {
            if ([metadata.type isEqualToString:type])
            {
                barCodeObject = (AVMetadataMachineReadableCodeObject *)[_prevLayer transformedMetadataObjectForMetadataObject:(AVMetadataMachineReadableCodeObject *)metadata];
                highlightViewRect = barCodeObject.bounds;
                detectionString = [(AVMetadataMachineReadableCodeObject *)metadata stringValue];
                break;
            }
        }
        
        if (detectionString != nil )
        {
            if ([detectionString isEqualToString:lastDetectedString ] == NO)
            {
                _label.text = detectionString;
                [lastDetectedString setString:detectionString];
                NSLog(@"Detected : %@", detectionString);
                NSLog(@"Detected : %@", lastDetectedString);
                AudioServicesPlaySystemSound(1103);
                [_session stopRunning];
                

                // Send a synchronous request
                
                NSString * url = [WEBSERVERURL stringByAppendingString:detectionString];
                
                NSLog(@"Attempting: %@", url);
                
                NSURLRequest * urlRequest = [NSURLRequest requestWithURL:
                                             [NSURL URLWithString:url]];
                NSURLResponse * response = nil;
                NSError * error = nil;
                NSData * data = [NSURLConnection sendSynchronousRequest:urlRequest
                                                      returningResponse:&response
                                                                  error:&error];
                
                if (error == nil)
                {
                    NSLog(@"got data: %@",
                          [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]);
                    
                    //parse out the json data
                    NSError* error;
                    NSDictionary* json = [NSJSONSerialization
                                          JSONObjectWithData:data
                                          options:kNilOptions
                                          error:&error];
                    
                    NSLog(@"Dictionary: %@", [json description]);
                    
                    NSString* item_num = [json objectForKey:@"item_num"];
                    
                    NSLog(@"Item Num: %@", item_num);
                    _label.text = item_num;
                }
                else
                {
                    NSLog(@"no data");
                }
                break;
            }
        }
        else
            _label.text = @"(none)";
    }

    _highlightView.frame = highlightViewRect;
}

@end