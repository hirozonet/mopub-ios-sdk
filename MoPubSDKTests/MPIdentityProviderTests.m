//
//  MPIdentityProviderTests.m
//
//  Copyright 2018-2021 Twitter, Inc.
//  Licensed under the MoPub SDK License Agreement
//  http://www.mopub.com/legal/sdk-license-agreement/
//

#import <XCTest/XCTest.h>
#import "MPConsentManager+Testing.h"
#import "MPIdentityProvider.h"
#import "MPIdentityProvider+Testing.h"

// These should match the constants with the same name in `MPIdentityProvider.m`
#define MOPUB_IDENTIFIER_DEFAULTS_KEY      @"com.mopub.identifier"
#define MOPUB_IDENTIFIER_LAST_SET_TIME_KEY @"com.mopub.identifiertime"

@interface MPIdentityProviderTests : XCTestCase
@end

@implementation MPIdentityProviderTests

- (void)setUp {
    [super setUp];

    // Clear out the MoPub identifier
    [NSUserDefaults.standardUserDefaults removeObjectForKey:MOPUB_IDENTIFIER_DEFAULTS_KEY];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:MOPUB_IDENTIFIER_LAST_SET_TIME_KEY];

    // Clear consent
    [MPConsentManager.sharedManager setUpConsentManagerForTesting];
}

- (void)tearDown {
    [super tearDown];

    [MPIdentityProvider resetTrackingAuthorizationStatusToDefault];
}

#pragma mark - IFA

- (void)testNoIfaWhenNoConsent {
    // Preconditions
    if (@available(iOS 14.0, *)) {
        MPIdentityProvider.trackingAuthorizationStatus = ATTrackingManagerAuthorizationStatusAuthorized;
    }
    MPConsentManager.sharedManager.rawIfa = @"some_real_ifa";
    MPConsentManager.sharedManager.forceIsGDPRApplicable = YES;

    // Retrieve the IFA
    NSString *ifa = MPIdentityProvider.ifa;
    XCTAssertNil(ifa);
}

- (void)testNoIfaWhenNotAllowedToTrack {
    // Preconditions
    if (@available(iOS 14.0, *)) {
        MPIdentityProvider.trackingAuthorizationStatus = ATTrackingManagerAuthorizationStatusDenied;
    }
    MPConsentManager.sharedManager.rawIfa = @"some_real_ifa";
    MPConsentManager.sharedManager.forceIsGDPRApplicable = YES;
    [MPConsentManager.sharedManager checkForDoNotTrackAndTransition];
    [MPConsentManager.sharedManager grantConsent];

    // Retrieve the IFA
    NSString *ifa = MPIdentityProvider.ifa;
    XCTAssertNil(ifa);
}

- (void)testIfaWhenAllowedAndConsented {
    // Preconditions
    if (@available(iOS 14.0, *)) {
        MPIdentityProvider.trackingAuthorizationStatus = ATTrackingManagerAuthorizationStatusAuthorized;
    }
    MPConsentManager.sharedManager.rawIfa = @"some_real_ifa";
    MPConsentManager.sharedManager.forceIsGDPRApplicable = YES;
    [MPConsentManager.sharedManager grantConsent];

    // Retrieve the IFA
    NSString *ifa = MPIdentityProvider.ifa;
    XCTAssertNotNil(ifa);
    XCTAssertTrue([ifa isEqualToString:@"some_real_ifa"]);
}

#pragma mark - IFV

- (void)testIfvExists {
    NSString *ifv = MPIdentityProvider.ifv;
    XCTAssertNotNil(ifv);
}

#pragma mark - MoPub Identifier

- (void)testGenerateMoPubIdentifier {
    NSString *mopubId = MPIdentityProvider.mopubId;
    XCTAssertNotNil(mopubId);
    XCTAssertNotNil([NSUserDefaults.standardUserDefaults objectForKey:MOPUB_IDENTIFIER_DEFAULTS_KEY]);
    XCTAssertNil([NSUserDefaults.standardUserDefaults objectForKey:MOPUB_IDENTIFIER_LAST_SET_TIME_KEY]);
}

- (void)testMoPubIdentifierSameUtcDay {
    NSString *mopubId = MPIdentityProvider.mopubId;
    XCTAssertNotNil(mopubId);
    XCTAssertNotNil([NSUserDefaults.standardUserDefaults objectForKey:MOPUB_IDENTIFIER_DEFAULTS_KEY]);
    XCTAssertNil([NSUserDefaults.standardUserDefaults objectForKey:MOPUB_IDENTIFIER_LAST_SET_TIME_KEY]);

    NSString *secondTryMopubId = MPIdentityProvider.mopubId;
    XCTAssertNotNil(secondTryMopubId);
    XCTAssert([secondTryMopubId isEqualToString:mopubId]);
}

- (void)testMoPubIdentifierFormat {
    // MoPub Identifier using `NSUUID` should match the string format generated by `CFUUIDRef`.
    // The standard format for UUIDs represented in ASCII is a string punctuated by hyphens,
    // for example 68753A44-4D6F-1226-9C60-0050E4C00067.
    NSString *mopubIdPattern = @"[0-9a-fA-F]{8}\\-[0-9a-fA-F]{4}\\-[0-9a-fA-F]{4}\\-[0-9a-fA-F]{4}\\-[0-9a-fA-F]{12}";

    // Retrieve unobfuscated MoPub ID
    NSString *mId = MPIdentityProvider.mopubId;
    XCTAssertNotNil(mId);
    NSLog(@"%@", mId);

    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:mopubIdPattern options:0 error:&error];
    NSArray *matches = [regex matchesInString:mId options:0 range:NSMakeRange(0, mId.length)];

    XCTAssertNil(error);
    XCTAssert(matches.count == 1);
}

- (void)testUpgradeOldMoPubIdentifierFormat {
    // Setup old MoPub ID
    NSDate *now = [NSDate date];
    [NSUserDefaults.standardUserDefaults setObject:@"mopub:11E8F75F-B0AE-461B-810C-18BF5EA59C71" forKey:MOPUB_IDENTIFIER_DEFAULTS_KEY];
    [NSUserDefaults.standardUserDefaults setObject:now forKey:MOPUB_IDENTIFIER_LAST_SET_TIME_KEY];

    // Retrieving MoPub ID will automatically upgrade
    NSString *mopubId = MPIdentityProvider.mopubId;
    XCTAssertNotNil(mopubId);
    XCTAssertTrue([mopubId isEqualToString:@"11E8F75F-B0AE-461B-810C-18BF5EA59C71"]);
    XCTAssertNil([NSUserDefaults.standardUserDefaults objectForKey:MOPUB_IDENTIFIER_LAST_SET_TIME_KEY]);
}

#pragma mark - App Tracking Transparency

- (void)testATTAuthorizationStatusDescriptionValueFillsCorrectly {
    if (@available(iOS 14.0, *)) {
        MPIdentityProvider.trackingAuthorizationStatus = ATTrackingManagerAuthorizationStatusNotDetermined;
        XCTAssert([kAppTrackingTransparencyDescriptionNotDetermined isEqualToString:MPIdentityProvider.trackingAuthorizationStatusDescription]);

        MPIdentityProvider.trackingAuthorizationStatus = ATTrackingManagerAuthorizationStatusAuthorized;
        XCTAssert([kAppTrackingTransparencyDescriptionAuthorized isEqualToString:MPIdentityProvider.trackingAuthorizationStatusDescription]);

        MPIdentityProvider.trackingAuthorizationStatus = ATTrackingManagerAuthorizationStatusDenied;
        XCTAssert([kAppTrackingTransparencyDescriptionDenied isEqualToString:MPIdentityProvider.trackingAuthorizationStatusDescription]);

        MPIdentityProvider.trackingAuthorizationStatus = ATTrackingManagerAuthorizationStatusRestricted;
        XCTAssert([kAppTrackingTransparencyDescriptionRestricted isEqualToString:MPIdentityProvider.trackingAuthorizationStatusDescription]);
    }
}

- (void)testAdvertisingTrackingEnabledValueFillsCorrectly {
    if (@available(iOS 14.0, *)) {
        MPIdentityProvider.trackingAuthorizationStatus = ATTrackingManagerAuthorizationStatusNotDetermined;
        XCTAssertFalse(MPIdentityProvider.advertisingTrackingEnabled);

        MPIdentityProvider.trackingAuthorizationStatus = ATTrackingManagerAuthorizationStatusAuthorized;
        XCTAssertTrue(MPIdentityProvider.advertisingTrackingEnabled);

        MPIdentityProvider.trackingAuthorizationStatus = ATTrackingManagerAuthorizationStatusDenied;
        XCTAssertFalse(MPIdentityProvider.advertisingTrackingEnabled);

        MPIdentityProvider.trackingAuthorizationStatus = ATTrackingManagerAuthorizationStatusRestricted;
        XCTAssertFalse(MPIdentityProvider.advertisingTrackingEnabled);
    }
}

@end
