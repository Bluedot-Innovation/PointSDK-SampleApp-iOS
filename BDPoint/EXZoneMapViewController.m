//
//  BDZoneMapViewController.m
//  BDPoint
//
//  Created by Christopher Hatton on 14/06/2014.
//  Copyright (c) 2014 Bluedot. All rights reserved.
//

#import <BDPointSDK.h>

#import "EXZoneMapViewController.h"
#import "EXNotificationStrings.h"


//  Declare constants
static float  fenceMapInset = 10.0f;
static float  minButtonHeight = 44.0f;


/*
 *  Anonymous category for local properties.
 */
@interface EXZoneMapViewController () <MKMapViewDelegate>

@property (nonatomic, readonly) MKMapView  *mapView;
@property (nonatomic) BDFenceOverlayRendererFactory  *fenceRendererFactory;

@property (nonatomic) NSMapTable  *fenceRendererCache;
@property (nonatomic) NSMapTable  *fenceCheckInStatuses;
@property (nonatomic) BDFence  *lastCheckedInFence;

@property (nonatomic) UIEdgeInsets  fenceMapInsets;

@end


@implementation EXZoneMapViewController
{
    UIColor  *fenceColourDefault;
    UIColor  *fenceColourCheckedIn;
    UIColor  *fenceColourCheckedInLast;
    
    MKMapView  *_mapView;
    float  _windowHeight;
}


- (id)init
{
    
    //  Create the view utilising the height of the main screen
    return( [ self initWithHeight: UIScreen.mainScreen.bounds.size.height ] );
}

- (id)initWithHeight: (float)height
{
    
    if ( ( self = [super init] ) != nil )
    {
        //  Set the view properties
        self.title = @"Map";
        _windowHeight = height;
        
        //  Set the colours to use for fences
        fenceColourDefault = UIColor.grayColor;
        fenceColourCheckedIn = UIColor.cyanColor;
        fenceColourCheckedInLast = UIColor.greenColor;

        _fenceCheckInStatuses = [ [ NSMapTable alloc ] initWithKeyOptions: NSPointerFunctionsStrongMemory|NSPointerFunctionsObjectPointerPersonality
                                                             valueOptions: NSPointerFunctionsStrongMemory|NSPointerFunctionsObjectPersonality
                                                                 capacity: 8 ];

        _fenceRendererFactory = [ [ BDFenceOverlayRendererFactory alloc ] initWithFillColor: UIColor.cyanColor
                                                                                strokeColor: UIColor.cyanColor
                                                                                strokeWidth: 2.0f
                                                                                      alpha: 0.6f ];
        _fenceRendererCache   = [ NSMapTable weakToStrongObjectsMapTable ];

        _fenceMapInsets = UIEdgeInsetsMake( fenceMapInset, fenceMapInset, fenceMapInset, fenceMapInset );

        void ( ^showFencesNotificationHandler)(NSNotification *) = ^( NSNotification *showFencesNotification )
        {
            NSSet  *fences = showFencesNotification.object;
            
            [ self.mapView setRegionToFitOverlays: fences
                                      withPadding: _fenceMapInsets
                                         animated: YES ];
        };

        [ NSNotificationCenter.defaultCenter addObserverForName: EXShowFencesOnMapNotification
                                                         object: nil
                                                          queue: [ NSOperationQueue mainQueue ]
                                                     usingBlock: showFencesNotificationHandler ];
    }
    
    return self;
}


/*
 *  Over-ride the loadView to programmatically setup the view.
 */
- (void)loadView
{
    CGRect  size = { 0.0f, 0.0f, UIScreen.mainScreen.bounds.size.width, _windowHeight };
    
    _mapView = [ [ MKMapView alloc ] initWithFrame: size ];

    //  Using showUserLocation will use continuous GPS
    _mapView.showsUserLocation = NO;
    _mapView.delegate = self;

    self.view = _mapView;
    [ self.view addSubview: [ self createShowLocationButton ] ];
}


- (MKMapView *)mapView
{
    return (MKMapView *)self.view;
}


- (void)setZones: (NSSet *)zones
{
    
    //  Remove all existing fence overlays
    for( BDFence *fence in _fenceCheckInStatuses.keyEnumerator )
    {
        [ self.mapView removeOverlay: fence ];
    }

    [ _fenceCheckInStatuses removeAllObjects ];

    //  Assign all of the fences in zone
    for( BDZoneInfo *zone in zones )
    {
        for( BDFence *fence in zone.fences )
        {
            [ _fenceCheckInStatuses setObject: @(NO) forKey: fence ];
        }
    }

    //  Add the fences as overlays to the map view
    [ self.mapView addOverlays: _fenceCheckInStatuses.keyEnumerator.allObjects ];

    [ self.mapView setRegionToFitAllOverlaysWithPadding: _fenceMapInsets
                                               animated: YES ];
}


/*
 *  The processing for when a fence has been checked into,.
 */
- (void)didCheckIntoFence:(BDFence *)fence
{
    
    //  Set the checked-in status for the fence to YES
    [ _fenceCheckInStatuses setObject: @(YES) forKey: fence ];

    [ self refreshFenceAppearance: fence ];
}


/*
 *  Zoom the map view to fit the zones.
 */
- (void)zoomToFitZones
{
    
    [ self.mapView setRegionToFitAllOverlaysWithPadding: _fenceMapInsets
                                               animated: YES ];
}


#pragma mark MKMapViewDelegate begin

- (MKOverlayRenderer *)mapView: (MKMapView *)mapView
            rendererForOverlay: (id<MKOverlay>)overlay
{
    NSAssert( [ overlay isKindOfClass: BDFence.class ], NSInternalInconsistencyException );
    
    BDFence  *fence = (BDFence *)overlay;
    MKOverlayRenderer  *renderer = [ _fenceRendererCache objectForKey: fence ];

    
    if ( renderer == nil )
    {
        renderer = [ _fenceRendererFactory rendererForFence: fence ];
        [ _fenceRendererCache setObject: renderer forKey: fence ];
        
        [ self refreshFenceAppearance: fence ];
    }

    return renderer;
}

#pragma mark MKMapViewDelegate end


/*
 *  Determine if a fence has been checked in.
 */
- (BOOL)hasCheckedIntoFence: (BDFence *)fence
{
    
    _lastCheckedInFence = fence;
    return [ (NSNumber *)[ _fenceCheckInStatuses objectForKey: fence ] boolValue ];
}


/*
 *  Refresh the fences.
 */
- (void)refreshFenceAppearance:(BDFence*)fence
{
    MKOverlayPathRenderer  *fenceRenderer = (MKOverlayPathRenderer *)[ self mapView: self.mapView rendererForOverlay: fence ];
    UIColor  *fenceColor;

    
    if ( fence == _lastCheckedInFence )
    {
        fenceColor = fenceColourCheckedInLast;
    }
    else if ( [ self hasCheckedIntoFence: fence ] == YES )
    {
        fenceColor = fenceColourCheckedIn;
    }
    else
    {
        fenceColor = fenceColourDefault;
    }

    //  Assign the colours to be rendered
    fenceRenderer.fillColor = fenceColor;
    fenceRenderer.strokeColor = fenceColor;
}


/*
 *  Button processing.
 *  The button appears 
 */
- (UIButton *)createShowLocationButton
{
    float  buttonHeight = ( _windowHeight / 10.0f );
    UIButton  *showLocationButton = [ UIButton buttonWithType: UIButtonTypeRoundedRect ];
    
    
    //  Ensure the minimum button height
    if ( buttonHeight < minButtonHeight )
    {
        buttonHeight = minButtonHeight;
    }
    
    //  Setup the button criteria
    showLocationButton.frame = CGRectMake( fenceMapInset, _windowHeight - buttonHeight - fenceMapInset, self.view.frame.size.width - ( fenceMapInset * 2.0f ), buttonHeight );

    showLocationButton.layer.cornerRadius = 6.0f;
    showLocationButton.layer.borderWidth = 1.5f;
    showLocationButton.layer.borderColor = [ [ UIColor colorWithRed: 66.0f / 255.0f
                                                              green: 155.0f / 255.0f
                                                               blue: 213.0f / 255.0f
                                                              alpha: 1.0f ] CGColor ];

    showLocationButton.backgroundColor = [ UIColor colorWithRed: 66.0f / 255.0f
                                                          green: 155.0f / 255.0f
                                                           blue: 213.0f / 255.0f
                                                          alpha: 0.75f ];
    
    [ showLocationButton setTitle: @"Hold to show device location" forState: UIControlStateNormal ];
    [ showLocationButton setTitleColor: [ UIColor whiteColor ] forState: UIControlStateNormal ];

    [ showLocationButton addTarget: self action: @selector(showLocation) forControlEvents: UIControlEventTouchDown ];
    [ showLocationButton addTarget: self action: @selector(hideLocation) forControlEvents: UIControlEventTouchUpInside ];
    
    return showLocationButton;
}


- (void)showLocation
{
    
    _mapView.showsUserLocation = YES;
}


- (void)hideLocation
{
    static BOOL  firstUsage = YES;
    
    if ( firstUsage == YES )
    {
        UIAlertView *msg = [ [ UIAlertView alloc] initWithTitle: @"Power Consumption"
                                                        message: @"Holding the button to show your location uses iOS Location Services that drains power at a high rate.\n\nWithout the button held, your actions will still trigger using the energy efficient Bluedot Point SDK."
                                                       delegate: nil
                                              cancelButtonTitle: @"OK"
                                              otherButtonTitles: nil ];
        [ msg show ];
        firstUsage = NO;
    }
    
    _mapView.showsUserLocation = NO;
}


/*
 *  Over-ride the did update user location delegate to move to the location of the user.
 */
- (void)mapView: (MKMapView *)mapView didUpdateUserLocation: (MKUserLocation *)userLocation
{
    MKCoordinateRegion  region;
    MKCoordinateSpan  span;
    CLLocationCoordinate2D  location;

    //  Create a span for the visibility of the map
    span.latitudeDelta = 0.005;
    span.longitudeDelta = 0.005;

    location.latitude = userLocation.coordinate.latitude;
    location.longitude = userLocation.coordinate.longitude;
    
    region.span = span;
    region.center = location;
    
    [ mapView setRegion: region animated: YES ];
}

@end