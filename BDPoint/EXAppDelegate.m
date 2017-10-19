//
//  Created by Bluedot Innovation
//  Copyright (c) 2016 Bluedot Innovation. All rights reserved.
//
//  Application delegate for Bluedot Demo App Project in Objective-C
//

#import <BDPointSDK.h>

#import "EXAppDelegate.h"

#import "EXZoneMapViewController.h"
#import "EXZoneChecklistViewController.h"
#import "EXAuthenticationViewController.h"
#import "EXNotificationStrings.h"
#import "UIWindow+BDVisible.h"


/*
 *  Anonymous category for local properties.
 */
@interface EXAppDelegate() <BDPointDelegate, UITabBarControllerDelegate, BDPRestartAlertDelegate>

@property (nonatomic) EXZoneChecklistViewController  *zoneChecklistViewController;
@property (nonatomic) EXZoneMapViewController        *zoneMapViewController;
@property (nonatomic) EXAuthenticationViewController *authenticationViewController;
@property (nonatomic) UITabBarController             *tabBarController;

@property (nonatomic) NSArray  *viewControllersNotRequiringZoneInfo;
@property (nonatomic) NSArray  *viewControllersRequiringZoneInfo;

@property (nonatomic) UIAlertController  *userInterventionForBluetoothDialog;
@property (nonatomic) UIAlertController  *userInterventionForLocationServicesNeverDialog;
@property (nonatomic) UIAlertController  *userInterventionForLocationServicesWhileInUseDialog;
@property (nonatomic) UIAlertController  *userInterventionForPowerModeDialog;

@property (nonatomic) UIAlertController  *userInterventionForZoneDialog;

@property (nonatomic) NSDateFormatter  *dateFormatter;

@end


@implementation EXAppDelegate

- (BOOL)application: (UIApplication *)application didFinishLaunchingWithOptions: (NSDictionary *)launchOptions
{
    BDLocationManager  *locationManager = BDLocationManager.instance;
    
    /*
     *  Assign the delegates for session handling and location updates to this class.
     */
    locationManager.sessionDelegate = self;
    locationManager.locationDelegate = self;

    [ self initializeUserInterface ];

    return YES;
}


- (BOOL)application: (UIApplication *)application
            openURL: (NSURL *)url
  sourceApplication: (NSString *)sourceApplication
         annotation: (id)annotation
{
    NSString  *parameterString = [ url query ];
    NSDictionary  *parameters = [ self parseURLParameters: parameterString ];

    NSString  *username = parameters[ BDPointUsernameKey ];
    NSString  *apiKey = parameters[ BDPointAPIKeyKey ];
    NSString  *packageName = parameters[ BDPointPackageNameKey ];

    BOOL isURLValid = ( username && apiKey && packageName );

    if ( isURLValid == YES )
    {
        NSString  *endpointURLString = parameters[ BDPointEndpointKey ];
        NSURL  *customEndpointURL = [ [ NSURL alloc ] initWithString: endpointURLString ];

        [ _authenticationViewController didReceiveRegistrationWithUsername: username
                                                                    apiKey: apiKey
                                                            andPackageName: packageName
                                                                    andURL: customEndpointURL ];
    }

    return isURLValid;
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // This method implementation must be present in AppDelegate
    // when integrating Bluedot Point SDK v1.x, even if it is empty.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // This method implementation must be present in AppDelegate
    // when integrating Bluedot Point SDK v1.x, even if it is empty.
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
}

- (void)applicationWillTerminate:(UIApplication *)application
{
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // For iOS9 this method implementation must be present in AppDelegate
    // when integrating Bluedot Point SDK v1.x, even if it is empty.
}

- (NSDictionary *)parseURLParameters: (NSString *)parameters
{
    NSMutableDictionary  *parameterDictionary = [ NSMutableDictionary new ];
    NSScanner  *scanner = [ NSScanner scannerWithString: parameters ];

    NSCharacterSet  *controlCharacters = [ NSCharacterSet characterSetWithCharactersInString: @"&=" ];

    scanner.charactersToBeSkipped = controlCharacters;

    NSString  *paramName;
    NSString  *paramValue;

    while( [ scanner isAtEnd ] == NO )
    {
        if ( [ scanner scanUpToCharactersFromSet: controlCharacters intoString: &paramName ] == NO )
        {
            break;
        }

        [ scanner setScanLocation: scanner.scanLocation + 1 ];

        if ( [ scanner scanUpToCharactersFromSet: controlCharacters intoString: &paramValue ] == NO )
        {
            break;
        }

        parameterDictionary[ paramName ] = [ paramValue urlDecode ];
    }

    return [ NSDictionary dictionaryWithDictionary: parameterDictionary ];
}


- (void)initializeUserInterface
{
    
    //  Setup a generic date formatter
    _dateFormatter = [ NSDateFormatter new ];
    [ _dateFormatter setDateFormat: @"dd-MMM-yyyy HH:mm" ];

    //  Create the tab bar controller
    _tabBarController = [ UITabBarController new ];
    _tabBarController.delegate = self;
    
    //  Create the window
    self.window = [ [ UIWindow alloc ] initWithFrame: UIScreen.mainScreen.bounds ];
    self.window.backgroundColor = UIColor.whiteColor;
    float  viewHeight = UIScreen.mainScreen.bounds.size.height - _tabBarController.tabBar.frame.size.height;

    _authenticationViewController = [ EXAuthenticationViewController new ];
    _zoneMapViewController        = [ [ EXZoneMapViewController alloc ] initWithHeight: viewHeight ];
    _zoneChecklistViewController  = [ EXZoneChecklistViewController new ];

    _authenticationViewController.tabBarItem.image = [ UIImage imageNamed: @"Authenticate" ];
    _zoneMapViewController.tabBarItem.image = [ UIImage imageNamed: @"Map" ];
    _zoneChecklistViewController.tabBarItem.image = [ UIImage imageNamed: @"Checklist" ];

    _viewControllersNotRequiringZoneInfo = @[ _authenticationViewController ];
    _viewControllersRequiringZoneInfo = @[ _zoneMapViewController, _zoneChecklistViewController ];
    [ _tabBarController setViewControllers: _viewControllersNotRequiringZoneInfo ];

    [ self startObservingShowFencesOnMapNotifications ];

    [ self.window setRootViewController: _tabBarController ];
    [ self.window addSubview: _tabBarController.view ];

    [ self.window makeKeyAndVisible ];
}


/**
 * Switches tab-bar controller to the Map view, whenever a EXShowFencesOnMap notification is received.
 */
-(void)startObservingShowFencesOnMapNotifications
{
    void ( ^showZonesNotificationHandler )(NSNotification *) = ^( NSNotification *showFencesNotification )
    {
        NSAssert( BDLocationManager.instance.authenticationState == BDAuthenticationStateAuthenticated, NSInternalInconsistencyException );

        [ _tabBarController setSelectedViewController: _zoneMapViewController ];
    };

    [ NSNotificationCenter.defaultCenter addObserverForName: EXShowFencesOnMapNotification
                                                     object: nil
                                                      queue: NSOperationQueue.mainQueue
                                                 usingBlock: showZonesNotificationHandler ];
}


#pragma mark BDPointDelegate implementation begin

- (void)willAuthenticateWithUsername: (NSString *)username
                              apiKey: (NSString *)apiKey
                         packageName: (NSString *)packageName
{
    NSLog( @"Authenticating with Point service" );
}


- (void)authenticationWasSuccessful
{
    
    NSLog( @"Authenticated successfully with Point service" );
}


- (void)authenticationWasDeniedWithReason: (NSString *)reason
{
    NSLog( @"Authentication with Point service denied, with reason: %@", reason );

    UIAlertController *alertController = [ UIAlertController alertControllerWithTitle: @"Authentication Denied"
                                                                              message: reason
                                                                       preferredStyle: UIAlertControllerStyleAlert ];
    
    UIAlertAction *OK = [ UIAlertAction actionWithTitle: @"OK" style: UIAlertActionStyleCancel handler: nil ];
    
    [ alertController addAction:OK ];
    
    [ _window.visibleViewController presentViewController: alertController animated: YES completion: nil ];
}


- (void)authenticationFailedWithError: (NSError *)error
{
    NSLog( @"Authentication with Point service failed, with reason: %@", error.localizedDescription );

    NSString  *title;
    NSString  *message;

    //  BDResponseError will be more conveniently exposed in the next version
    BOOL isConnectionError = ( error.userInfo[ EXResponseError ] == NSURLErrorDomain );
    
    if ( isConnectionError == YES )
    {
        title = @"No data connection?";
        message = @"Sorry, but there was a problem connecting to Bluedot servers.\n"
                  "Please check you have a data connection, and that flight mode is disabled, and try again.";
    }
    else
    {
        title = @"Authentication Failed";
        message = error.localizedDescription;
    }

    UIAlertController *alertController = [ UIAlertController alertControllerWithTitle: title
                                                                              message: message
                                                                       preferredStyle: UIAlertControllerStyleAlert ];
    
    UIAlertAction *OK = [ UIAlertAction actionWithTitle: @"OK" style: UIAlertActionStyleCancel handler: nil ];
    
    [ alertController addAction:OK ];
    
    [ _window.visibleViewController presentViewController: alertController animated: YES completion: nil ];
}


- (void)didEndSession
{
    NSLog( @"Logged out" );

    [ self onDidEndSession ];
}

- (void)didEndSessionWithError: (NSError *)error
{
    NSLog( @"Logged out with error: %@", error.localizedDescription );

    [ self onDidEndSession ];
}

- (void)onDidEndSession
{
    [ _tabBarController setViewControllers: _viewControllersNotRequiringZoneInfo animated: NO ];
}


/*
 *  This method is passed the Zone information utilised by the Bluedot SDK.
 */
- (void)didUpdateZoneInfo: (NSSet *)zones
{
    NSLog( @"Point service updated with %lu zones", (unsigned long)zones.count );

    NSArray  *viewControllers;

    if ( zones && zones.count > 0 )
    {
        viewControllers = [ _viewControllersNotRequiringZoneInfo arrayByAddingObjectsFromArray: _viewControllersRequiringZoneInfo ];
    }
    else
    {
        viewControllers = _viewControllersNotRequiringZoneInfo;
        if ( BDLocationManager.instance.authenticationState == BDAuthenticationStateAuthenticated && UIApplication.sharedApplication.applicationState != UIApplicationStateBackground )
        {
            if ( _userInterventionForZoneDialog == nil )
            {
                NSString *message = [ NSString stringWithFormat: @"No data available on the backend. To start testing, please create at least one zone with a fence and an action to trigger when the device enters the location on the backend using our friendly dashboard." ];
                
                _userInterventionForZoneDialog = [ UIAlertController alertControllerWithTitle: @"Information"
                                                                                      message: message
                                                                               preferredStyle: UIAlertControllerStyleAlert ];
                
                UIAlertAction *OK = [ UIAlertAction actionWithTitle: @"OK" style: UIAlertActionStyleCancel handler:nil ];
                UIAlertAction *goToPointAccess = [ UIAlertAction actionWithTitle: @"Go to Point Access" style: UIAlertActionStyleDefault handler: ^(UIAlertAction *action) {
                    NSURL *pointAccessURL = [ NSURL URLWithString: @"https://www.pointaccess.bluedot.com.au/pointaccess-v1/" ];
                    [ [ UIApplication sharedApplication ] openURL: pointAccessURL ];
                } ];
                
                [ _userInterventionForZoneDialog addAction: OK ];
                [ _userInterventionForZoneDialog addAction: goToPointAccess ];
                
            }
            [ _window.visibleViewController presentViewController: _userInterventionForZoneDialog animated: YES completion: nil ];
        }
    }

    //  Enable the view controllers when zone information has been received
    [ _tabBarController setViewControllers: viewControllers
                                  animated: YES ];

    //  Assign the zone information to the Checklist and Map for display
    _zoneChecklistViewController.zones = zones;
    _zoneMapViewController.zones       = zones;
}

/*
 *  A fence with a Custom Action has been checked into; display an alert to notify the user.
 */
- (void)didCheckIntoFence: (BDFenceInfo *)fence
                   inZone: (BDZoneInfo *)zoneInfo
               atLocation: (BDLocationInfo *)location
             willCheckOut: (BOOL)willCheckOut
           withCustomData: (NSDictionary *)customData
{
    NSString *message = [ NSString stringWithFormat: @"You have checked into fence '%@' in zone '%@', at %@",
                         fence.name, zoneInfo.name, [ _dateFormatter stringFromDate: location.timestamp ] ];
    
    [ self presentNotificationWithMessage: message ];

    //  Update the status of a fence in the Map
    [ _zoneMapViewController didCheckIntoFence: fence ];

    //  Update the status of a fence in the Checklist
    [ _zoneChecklistViewController didCheckIntoFence: fence
                                              inZone: zoneInfo ];
}

/*
 *  A fence with a Custom Action has been checked out from; display an alert to notify the user.
 */
- (void)didCheckOutFromFence: (BDFenceInfo *)fence
                      inZone: (BDZoneInfo *)zoneInfo
                      onDate: (NSDate *)date
                withDuration: (NSUInteger)checkedInDuration
              withCustomData: (NSDictionary *)customData
{
    NSString *message = [ NSString stringWithFormat: @"You left '%@' in zone '%@' after %lu minutes",
                         fence.name, zoneInfo.name, (unsigned long)checkedInDuration ];
    
    [ self presentNotificationWithMessage: message ];
}

/*
 *  A beacon with a Custom Action has been checked into; display an alert to notify the user.
 */
- (void)didCheckIntoBeacon: (BDBeaconInfo *)beacon
                    inZone: (BDZoneInfo *)zoneInfo
                atLocation: (BDLocationInfo *)location
             withProximity: (CLProximity)proximity
              willCheckOut: (BOOL)willCheckOut
            withCustomData: (NSDictionary *)customData
{
    NSString *proximityString;

    switch(proximity)
    {
        default:
        case CLProximityUnknown:   proximityString = @"Unknown";   break;
        case CLProximityImmediate: proximityString = @"Immediate"; break;
        case CLProximityNear:      proximityString = @"Near";      break;
        case CLProximityFar:       proximityString = @"Far";       break;
    }

    NSString *message = [ NSString stringWithFormat: @"You have checked into beacon '%@' in zone '%@' with proximity %@ at %@",
                         beacon.name, zoneInfo.name, proximityString, [ _dateFormatter stringFromDate: location.timestamp ] ];

    [ self presentNotificationWithMessage: message ];

    //  Update the state of a beacon on the Map
    [ _zoneMapViewController didCheckIntoBeacon: beacon ];

    //  Update the state of a beacon on the Checklist
    [ _zoneChecklistViewController didCheckIntoBeacon: beacon
                                               inZone: zoneInfo ];
}

/*
 *  A beacon with a Custom Action has been checked out from; display an alert to notify the user.
 */
- (void)didCheckOutFromBeacon: (BDBeaconInfo *)beacon
                       inZone: (BDZoneInfo *)zoneInfo
                withProximity: (CLProximity)proximity
                       onDate: (NSDate *)date
                 withDuration: (NSUInteger)checkedInDuration
               withCustomData: (NSDictionary *)customData
{
    NSString *message = [ NSString stringWithFormat: @"You left beacon '%@' in zone '%@', after %lu minutes",
                                                     beacon.name, zoneInfo.name, (unsigned long)checkedInDuration ];
    
    [ self presentNotificationWithMessage: message ];
}

/*
 *  This method is part of the Bluedot location delegate and is called when Bluetooth is required by the SDK but is not enabled
 *  on the device; requiring user intervention.
 */
- (void)didStartRequiringUserInterventionForBluetooth
{
    if ( _userInterventionForBluetoothDialog == nil )
    {
        NSString  *title = @"Bluetooth Required";
        NSString  *message = @"There are nearby Beacons which cannot be detected because Bluetooth is disabled.  Re-enable Bluetooth to restore full functionality.";
        
        _userInterventionForBluetoothDialog = [ UIAlertController alertControllerWithTitle: title
                                                                                   message: message
                                                                            preferredStyle: UIAlertControllerStyleAlert ];
        
        UIAlertAction *dismiss = [ UIAlertAction actionWithTitle: @"Dismiss" style: UIAlertActionStyleCancel handler: nil ];
        [ _userInterventionForBluetoothDialog addAction: dismiss ];
    }
    
    [ _window.visibleViewController presentViewController: _userInterventionForBluetoothDialog animated: YES completion: nil ];
}

/*
 *  This method is part of the Bluedot location delegate; it is called if user intervention on the device had previously been
 *  required to enable Bluetooth and either user intervention has enabled Bluetooth or the Bluetooth service is no longer required.
 */
- (void)didStopRequiringUserInterventionForBluetooth
{
    [ _userInterventionForBluetoothDialog dismissViewControllerAnimated: YES completion: nil ];
}

/*
 *  This method is part of the Bluedot location delegate and is called when Location Services are not enabled
 *  on the device; requiring user intervention.
 */
- (void)didStartRequiringUserInterventionForLocationServicesAuthorizationStatus:(CLAuthorizationStatus)authorizationStatus
{

    if(authorizationStatus == kCLAuthorizationStatusDenied)
    {
        if ( _userInterventionForLocationServicesNeverDialog == nil )
        {
            NSString  *appName = [ NSBundle.mainBundle objectForInfoDictionaryKey: @"CFBundleDisplayName" ];
            NSString  *title = @"Location Services Required";
            NSString  *message = [ NSString stringWithFormat: @"This App requires Location Services which are currently set to disabled.  To restore Location Services, go to :\nSettings → Privacy →\nLocation Settings →\n%@ ✓", appName ];

            _userInterventionForLocationServicesNeverDialog = [ UIAlertController alertControllerWithTitle: title
                                                                                              message: message
                                                                                       preferredStyle: UIAlertControllerStyleAlert ];

        }

        UIViewController *currentPresentedViewController = _window.rootViewController.presentedViewController;
        if([currentPresentedViewController isKindOfClass:[UIAlertController class]])
        {
            [currentPresentedViewController dismissViewControllerAnimated:YES completion:^(void){
                [ _window.visibleViewController presentViewController: _userInterventionForLocationServicesNeverDialog animated: YES completion: nil ];
            }];
        }
        else
        {
            [ _window.visibleViewController presentViewController: _userInterventionForLocationServicesNeverDialog animated: YES completion: nil ];
        }
    }
    else if(authorizationStatus == kCLAuthorizationStatusAuthorizedWhenInUse) {


        if (_userInterventionForLocationServicesWhileInUseDialog == nil) {
            NSString *title = @"Location Services set to 'While in Use'";
            NSString *message = [NSString stringWithFormat:@"You can ask for further location permission from user via this delegate method"];

            _userInterventionForLocationServicesWhileInUseDialog = [UIAlertController alertControllerWithTitle:title
                                                                                                       message:message
                                                                                                preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction *dismiss = [UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:nil];
            [_userInterventionForLocationServicesWhileInUseDialog addAction:dismiss];
        }

        UIViewController *currentPresentedViewController = _window.rootViewController.presentedViewController;
        if([currentPresentedViewController isKindOfClass:[UIAlertController class]])
        {
            [currentPresentedViewController dismissViewControllerAnimated:YES completion:^(void){
                [ _window.visibleViewController presentViewController: _userInterventionForLocationServicesWhileInUseDialog animated: YES completion: nil ];
            }];
        }
        else
        {
            [ _window.visibleViewController presentViewController: _userInterventionForLocationServicesWhileInUseDialog animated: YES completion: nil ];
        }
    }
    
}

/*
 *  This method is part of the Bluedot location delegate; it is called if user intervention on the device had previously been
 *  required to enable Location Services and either Location Services has been enabled or the user is no longer within an
 *  authenticated session, thereby no longer requiring Location Services.
 */
- (void)didStopRequiringUserInterventionForLocationServicesAuthorizationStatus:(CLAuthorizationStatus)authorizationStatus
{
    UIViewController *currentPresentedViewController = _window.rootViewController.presentedViewController;
    if([currentPresentedViewController isKindOfClass:[UIAlertController class]])
    {
        [currentPresentedViewController dismissViewControllerAnimated:YES completion:nil];
    }
}

/*
 *  This method is part of the Bluedot location delegate and is called when Low Power mode is enabled
 *  on the device; requiring user intervention to restore full SDK precision.
 */
- (void)didStartRequiringUserInterventionForPowerMode
{
    if ( _userInterventionForPowerModeDialog == nil )
    {
        NSString  *title = @"Low Power Mode";
        NSString  *message = [ NSString stringWithFormat: @"Low Power Mode has been enabled on this device.  To restore full location precision, disable the setting at :\nSettings → Battery → Low Power Mode" ];

        _userInterventionForPowerModeDialog = [ UIAlertController alertControllerWithTitle: title
                                                                                   message: message
                                                                            preferredStyle: UIAlertControllerStyleAlert ];
    }

    [ _window.visibleViewController presentViewController: _userInterventionForPowerModeDialog animated: YES completion: nil ];
}



- (void)didStopRequiringUserInterventionForPowerMode
{
    [ _userInterventionForPowerModeDialog dismissViewControllerAnimated: YES completion: nil ];
}

#pragma mark BDPointDelegate implementation end


/*
 *  Post a notifiction message.
 */
- (void)presentNotificationWithMessage: (NSString *)message
{
    UIApplicationState applicationState = UIApplication.sharedApplication.applicationState;
    
    switch( applicationState )
    {
            // In the foreground: display notification directly to the user
        case UIApplicationStateActive:
        {
            UIAlertController *alertController = [ UIAlertController alertControllerWithTitle: @"Application notification"
                                                                                      message: message
                                                                               preferredStyle: UIAlertControllerStyleAlert ];
            
            UIAlertAction *OK = [ UIAlertAction actionWithTitle: @"OK" style: UIAlertActionStyleCancel handler: nil ];
            
            [ alertController addAction:OK ];
            
            [ _window.visibleViewController presentViewController: alertController animated: YES completion: nil ];
        }
            break;
            
            // If not in the foreground: deliver a local notification
        default:
        {
            UILocalNotification *notification = [ UILocalNotification new ];
            notification.alertBody = message;
            
            [ UIApplication.sharedApplication presentLocalNotificationNow: notification ];
        }
            break;
    }
}


#pragma mark App Restart delegate start

- (NSString *)restartAlertTitle
{
    return( @"Restart BDPoint App by touching this message" );
}

#pragma mark App Restart delegate end

#pragma mark UITabBarControllerDelegate implementation begin

- (BOOL)tabBarController: (UITabBarController *)tabBarController shouldSelectViewController: (UIViewController *)viewController
{
    BOOL isDoubleTapOnMap = ( viewController == _zoneMapViewController ) && ( viewController == tabBarController.selectedViewController );

    
    if ( isDoubleTapOnMap == YES )
    {
        [ _zoneMapViewController zoomToFitZones ];
    }

    return YES;
}

#pragma mark UITabBarControllerDelegate implementation end

@end
