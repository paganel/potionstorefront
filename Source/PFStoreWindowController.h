//
//  PFStoreWindowController.h
//  PotionStoreFront
//
//  Created by Andy Kim on 7/26/08.
//  Copyright 2008 Potion Factory LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PFOrder;
@class PFAddress;
@class PFBackgroundView;

@interface PFStoreWindowController : NSWindowController
{
	IBOutlet PFBackgroundView *headerView;
	IBOutlet PFBackgroundView *mainContentView;
	
	IBOutlet NSTextField *headerTitleField;
	IBOutlet NSTextField *headerStepsField;
	IBOutlet NSButton *primaryButton;
	IBOutlet NSButton *secondaryButton;
	IBOutlet NSProgressIndicator *progressSpinner;
	
	// -----
	// STUFF FOR PRICING VIEW
	IBOutlet NSView *pricingView;
	IBOutlet NSCollectionView *productCollectionView;
	IBOutlet NSTextField *orderTotalField;

	// -----
	// STUFF FOR BILLING VIEW
	IBOutlet NSView *billingView;

	IBOutlet NSView *addressSelectionContainerView;

	// Labels
	IBOutlet NSTextField *firstNameLabel;
	IBOutlet NSTextField *lastNameLabel;
	IBOutlet NSTextField *address1Label;
	IBOutlet NSTextField *cityLabel;
	IBOutlet NSTextField *stateLabel;
	IBOutlet NSTextField *zipcodeLabel;
	IBOutlet NSTextField *emailLabel;
	IBOutlet NSTextField *creditCardNumberLabel;
	IBOutlet NSTextField *creditCardSecurityCodeLabel;
	IBOutlet NSTextField *creditCardExpirationLabel;

	// Input Fields
	IBOutlet NSTextField *creditCardNumberField;
	IBOutlet NSTextField *creditCardExpirationMonthField;
	IBOutlet NSTextField *creditCardExpirationYearField;
	
	// Pop up buttons
	IBOutlet NSPopUpButton *countryPopUpButton;
	IBOutlet NSPopUpButton *addressPopUpButton;
	
	IBOutlet NSArrayController *countriesArrayController;

	PFBackgroundView *overlayView;
	PFAddress *customAddress;

	// -----
	// STUFF FOR THANK YOU VIEW
	IBOutlet NSView *thankYouView;

	id delegate;

	NSURL *storeURL;
	PFOrder *order;
}

+ (id)sharedController;

- (id)delegate;
- (void)setDelegate:(id)object;

- (PFOrder *)order;
- (NSURL *)storeURL;
- (void)setStoreURL:(NSURL *)URL;

- (IBAction)showPricing:(id)sender;
- (IBAction)showBillingInformation:(id)sender;
- (IBAction)showThankYou:(id)sender;

- (IBAction)updateOrderLineItems:(id)sender;
- (IBAction)purchase:(id)sender;
- (IBAction)goBack:(id)sender;
- (IBAction)selectAddress:(id)sender;
- (IBAction)selectCountry:(id)sender;

// Private
- (NSInteger)p_countOfAddresses;
- (void)p_setupAddressPopUpButton;
- (void)p_setEnabled:(BOOL)enabled toAllControlsInView:(NSView *)view;
- (void)p_setContentView:(NSView *)view;
- (void)p_setHeaderTitle:(NSString *)title;
- (BOOL)p_validateOrder;

@end
