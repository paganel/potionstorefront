//
//  PFStoreWindowController.m
//  PotionStoreFront
//
//  Created by Andy Kim on 7/26/08.
//  Copyright 2008 Potion Factory LLC. All rights reserved.
//

#import "PFStoreWindowController.h"
#import "PotionStoreFront.h"
#import "PFBackgroundView.h"
#import "PFCollectionRow.h"

#import <AddressBook/AddressBook.h>

@implementation PFStoreWindowController

static PFStoreWindowController *gController = nil;

+ (id)sharedController
{
	if (gController == nil) {
		gController = [[PFStoreWindowController alloc] init];
		[gController window]; // Load the whole nib immediately
	}

	return gController;
}

- (id)init
{
	self = [super initWithWindowNibName:@"Store"];
	if (self) {
		order = [[PFOrder alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[storeURL release];
	[productsPlistURL release];
	[customAddress release];
	[order release];
	[super dealloc];
}

- (void)awakeFromNib
{
	[self window];

	[headerTitleField setTextColor:[NSColor colorWithCalibratedRed:201/255.0 green:220/255.0 blue:255/255.0 alpha:1.0]];
	[headerStepsField setTextColor:[NSColor colorWithCalibratedRed:201/255.0 green:220/255.0 blue:255/255.0 alpha:1.0]];

	// Default kerning on Helvetica Neue UltraLight is too small
	NSMutableAttributedString *as = [[[headerTitleField attributedStringValue] mutableCopy] autorelease];
	[as addAttribute:NSKernAttributeName value:[NSNumber numberWithFloat:1.2] range:NSMakeRange(0, [as length])];
	[headerTitleField setAttributedStringValue:as];

	[mainContentView setBackgroundColor:[NSColor colorWithCalibratedWhite:0.95 alpha:1.0]];

	[headerView setGradient:
	 [[[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedRed:25/255.0 green:36/255.0 blue:43/255.0 alpha:1.0]
									endingColor:[NSColor colorWithCalibratedRed:25/255.0 green:31/255.0 blue:38/255.0 alpha:1.0]] autorelease]];

	NSArray *countries = [NSArray arrayWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"countries" ofType:@"plist"]];
	[countriesArrayController setContent:countries];

	[self showPricing:nil];
}

static void PFUnbindEverythingInViewTree(NSView *view)
{
	if (view == nil) return; // just in case

	for (NSView *subview in view.subviews) {
		PFUnbindEverythingInViewTree(subview);
	}

	NSMutableArray *objectsToRemoveBindingsFrom = [NSMutableArray arrayWithObject:view];

	if ([view respondsToSelector:@selector(cell)]) {
		NSCell *cell = [(NSControl *)view cell];
		if (cell)
			[objectsToRemoveBindingsFrom addObject:cell];
	}
	if ([view respondsToSelector:@selector(cells)]) {
		NSArray *cells = [(id)view cells];
		if (cells)
			[objectsToRemoveBindingsFrom addObjectsFromArray:cells];
	}

	for (id obj in objectsToRemoveBindingsFrom) {
		if ([obj respondsToSelector:@selector(exposedBindings)]) {
			for (NSString *binding in [obj exposedBindings]) {
				NSDictionary *info = [obj infoForBinding:binding];
				if (info) {
					[obj unbind:binding];
				}
			}
		}
	}
}

- (void)close
{
	// Unbind everything so that circular retain cycles are released and everything can get deallocated
	PFUnbindEverythingInViewTree([[self window] contentView]);
	PFUnbindEverythingInViewTree(pricingView);
	PFUnbindEverythingInViewTree(billingView);
	PFUnbindEverythingInViewTree(thankYouView);
	[super close];
	[self autorelease];
	gController = nil;
}

#pragma mark -
#pragma mark Actions

- (IBAction)showPricing:(id)sender
{
	[self p_setContentView:pricingView];
	[self p_setHeaderTitle:NSLocalizedString(@"Purchase", nil)];
	[headerStepsField setStringValue:NSLocalizedString(@"Step 1 / 2", nil)];

	[primaryButton setTitle:NSLocalizedString(@"Next", nil)];
	[primaryButton setAction:@selector(showBillingInformation:)];

	[secondaryButton setTitle:NSLocalizedString(@"Cancel", nil)];
	[secondaryButton setAction:@selector(done:)];

	[tertiaryButton setHidden:NO];

	[lockImageView setHidden:YES];

	[[self window] recalculateKeyViewLoop];
}

- (IBAction)showBillingInformation:(id)sender
{
	if ([order totalAmount] == 0) {
		[orderTotalField setTextColor:[[NSColor redColor] shadowWithLevel:0.15]];
		NSBeep();
		return;
	}

	[self p_setContentView:billingView];
	[self p_setHeaderTitle:NSLocalizedString(@"Billing Information", nil)];
	[headerStepsField setStringValue:NSLocalizedString(@"Step 2 / 2", nil)];

	[primaryButton setTitle:NSLocalizedString(@"Purchase", nil)];
	[primaryButton setAction:@selector(purchase:)];

	[secondaryButton setTitle:NSLocalizedString(@"Go Back", nil)];
	[secondaryButton setAction:@selector(showPricing:)];

	[tertiaryButton setHidden:YES];

	[lockImageView setHidden:NO];

	// If there's one or less addresses in address book, hide the address selection dropdown
	if ([self p_countOfAddresses] <= 1) {
		NSRect wframe = [[self window] frame];
		CGFloat diff = NSHeight([addressSelectionContainerView frame]);
		wframe.size.height -= diff;
		wframe.origin.y += diff;
		[addressSelectionContainerView removeFromSuperview];
		[[self window] setFrame:wframe display:YES];
		addressPopUpButton = nil;
	}
	// Otherwise, populate the dropdown
	else {
		[self p_setupAddressPopUpButton];
	}

	// If name is blank, put focus there
	if ([[firstNameField stringValue] length] == 0)
		[[self window] makeFirstResponder:firstNameField];
	// otherwise, if address is blank, put focus there
	else if ([[address1Field stringValue] length] == 0)
		[[self window] makeFirstResponder:address1Field];
	// otherwise, if email is blank, put focus there
	else if ([[emailField stringValue] length] == 0)
		[[self window] makeFirstResponder:emailField];
	// otherwise put focus in credit card number field
	else
		[[self window] makeFirstResponder:creditCardNumberField];
}

- (IBAction)showThankYou:(id)sender
{
	[self p_setContentView:thankYouView];
	[self p_setHeaderTitle:NSLocalizedString(@"Thank You", nil)];
	[headerStepsField setStringValue:@""];

	[primaryButton setTitle:NSLocalizedString(@"Done", nil)];
	[primaryButton setAction:@selector(done:)];

	[secondaryButton setHidden:YES];

	[lockImageView setHidden:YES];
}

- (IBAction)updatedOrderLineItems:(id)sender
{
	// Reset to regular text color in case the error color got set
	[orderTotalField setTextColor:[NSColor controlTextColor]];
}

- (IBAction)purchase:(id)sender
{
	if ([self p_validateOrder]) {
		[[self window] makeFirstResponder:[[self window] initialFirstResponder]];
		[self p_setEnabled:NO toAllControlsInView:[[self window] contentView]];

		[progressSpinner startAnimation:self];

		[order setDelegate:self];
		[order setSubmitURL:[NSURL URLWithString:[[storeURL absoluteString] stringByAppendingPathComponent:@"order.json"]]];
		[order submitInBackground];
	}
	else {
		NSBeep();
	}
}

- (IBAction)done:(id)sender
{
	[self close];
	[NSApp endSheet:[self window] returnCode:NSCancelButton];
}

- (IBAction)goBack:(id)sender
{
	[self close];
	[NSApp endSheet:[self window] returnCode:NSCancelButton];
}

- (IBAction)selectAddress:(id)sender
{
	NSInteger index = [sender indexOfItem:[sender selectedItem]];

	if (index < [self p_countOfAddresses]) {
		NSString *label = [[[[ABAddressBook sharedAddressBook] me] valueForProperty:kABAddressProperty] labelAtIndex:index];
		PFAddress *address = [[[order billingAddress] copy] autorelease];
		[address fillUsingAddressBookAddressWithLabel:label];
		[order setBillingAddress:address];
	}
	else if (customAddress) {
		[order setBillingAddress:customAddress];
	}
}

- (IBAction)selectCountry:(id)sender
{
	[self controlTextDidChange:nil];
}

#pragma mark -
#pragma mark Delegate

- (void)didFinishFetchingProducts:(NSArray *)products error:(NSError *)error
{
	[productFetchProgressSpinner stopAnimation:self];
	[productFetchProgressSpinner removeFromSuperview];

	if (error) {
		[NSApp presentError:error modalForWindow:[self window] delegate:nil didPresentSelector:nil contextInfo:NULL];
	}
	else {
		[productCollectionView setContent:products];
		[order setLineItems:[products filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"checked = YES"]]];
	}
}

- (void)orderDidFinishSubmitting:(PFOrder *)anOrder error:(NSError *)error
{
	[progressSpinner stopAnimation:self];

	if (error == nil) {
		[self p_setEnabled:YES toAllControlsInView:[[self window] contentView]];

		// Wipe the credit card information before notifying the delegate
		[anOrder setCreditCardNumber:nil];
		[anOrder setCreditCardSecurityCode:nil];
		[anOrder setCreditCardExpirationMonth:nil];
		[anOrder setCreditCardExpirationYear:nil];

		if ([[self delegate] respondsToSelector:@selector(orderDidFinishCharging:)]) {
			[[self delegate] orderDidFinishCharging:anOrder];
		}

		[self showThankYou:self];
	}
	else {
		[NSApp presentError:error modalForWindow:[self window] delegate:self didPresentSelector:@selector(didPresentOrderSubmitError:) contextInfo:NULL];
	}
}

- (void)didPresentOrderSubmitError:(BOOL)didRecover
{
	[self p_setEnabled:YES toAllControlsInView:[[self window] contentView]];

	// Trigger a key value observer update so that the credit card buttons get their
	// enable state set correctly again
	[order willChangeValueForKey:@"creditCardNumber"];
	[order didChangeValueForKey:@"creditCardNumber"];
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	if ([aNotification object] == creditCardNumberField) return;
	if ([aNotification object] == creditCardExpirationMonthField) return;
	if ([aNotification object] == creditCardExpirationYearField) return;

	// Should get here iff address is edited

	// Only add the custom address item once
	if (customAddress == nil) {
		[addressPopUpButton addItemWithTitle:NSLocalizedString(@"other", nil)];
		[addressPopUpButton selectItemAtIndex:[addressPopUpButton numberOfItems] - 1];

		customAddress = [[order billingAddress] copy];
		[order setBillingAddress:customAddress];
	}
	else {
		[customAddress release];
		customAddress = [[order billingAddress] copy];
		[order setBillingAddress:customAddress];
		// Select the custom address in the pop up
		[addressPopUpButton selectItemAtIndex:[addressPopUpButton numberOfItems] - 1];
	}
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
	// It would be nice to validate in control:isValidObject:, but I can't figure out how to customize
	// the error message there

	// Validate the credit card number right away
	if (control == creditCardNumberField) {
		NSString *ccnum = [creditCardNumberField stringValue];
		if ([ccnum length] != 0) {
			NSError *error = nil;
			if (![order validateValue:&ccnum forKey:@"creditCardNumber" error:&error]) {
				NSAlert *alert = [NSAlert alertWithError:error];
				[alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:nil contextInfo:NULL];
				return NO;
			}
		}
	}

	return YES;
}

#pragma mark Outline View Delegate

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
	return NO;
}

#pragma mark -
#pragma mark Accessors

- (id)delegate { return delegate; }
- (void)setDelegate:(id)object { delegate = object; }

- (PFOrder *)order { return order; }

- (NSURL *)storeURL { return storeURL; }
- (void)setStoreURL:(NSURL *)value
{
	if (storeURL != value) {
		[storeURL release]; storeURL = [value copy];
		if ([[storeURL scheme] isEqualToString:@"https"] == NO) {
			// Don't show lock if it's not really secure
			[lockImageView removeFromSuperview];
			lockImageView = nil;
		}
	}
}

- (NSURL *)productsPlistURL { return productsPlistURL; }
- (void)setProductsPlistURL:(NSURL *)value
{
	if (productsPlistURL != value) {
		[productsPlistURL release];
		productsPlistURL = [value copy];

		// Grab products from server
		[productFetchProgressSpinner startAnimation:self];
		[PFProduct beginFetchingProductsFromURL:productsPlistURL delegate:self];
	}
}

#pragma mark -
#pragma mark Private

- (NSInteger)p_countOfAddresses
{
	ABMultiValue *addresses = [[[ABAddressBook sharedAddressBook] me] valueForProperty:kABAddressProperty];
	return [addresses count];
}

- (void)p_setupAddressPopUpButton
{
	ABMultiValue *addresses = [[[ABAddressBook sharedAddressBook] me] valueForProperty:kABAddressProperty];

	[addressPopUpButton removeAllItems];

	for (NSUInteger i = 0; i < [addresses count]; i++) {
		NSString *label = [addresses labelAtIndex:i];

		if ([label isEqualToString:kABHomeLabel])
			label = NSLocalizedString(@"home", nil);
		else if ([label isEqualToString:kABWorkLabel])
			label = NSLocalizedString(@"work", nil);

		[addressPopUpButton addItemWithTitle:label];
	}

	[addressPopUpButton setTarget:self];
	[addressPopUpButton setAction:@selector(selectAddress:)];
}

- (void)p_setEnabled:(BOOL)enabled toAllControlsInView:(NSView *)view
{
	NSEnumerator *e = [[view subviews] objectEnumerator];
	NSView *subview = nil;
	while ((subview = [e nextObject])) {
		[self p_setEnabled:enabled toAllControlsInView:subview];
	}

	if ([view respondsToSelector:@selector(setEnabled:)]) {
		[(NSControl *)view setEnabled:enabled];
	}
}

- (void)p_setContentView:(NSView *)view
{
	CGFloat diff = NSHeight([mainContentView frame]) - NSHeight([view frame]);
	NSRect wframe = [[self window] frame];
	wframe.origin.y += diff;
	wframe.size.height -= diff;
	[[mainContentView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
	[[self window] setFrame:wframe display:YES animate:YES];
	[view setFrame:[mainContentView bounds]];
	[mainContentView addSubview:view positioned:NSWindowBelow relativeTo:nil];
	[[self window] recalculateKeyViewLoop];
}

- (void)p_setHeaderTitle:(NSString *)title
{
	NSMutableAttributedString *as = [[[headerTitleField attributedStringValue] mutableCopy] autorelease];
	[as replaceCharactersInRange:NSMakeRange(0, [as length]) withString:title];
	[headerTitleField setAttributedStringValue:as];
}

- (BOOL)p_validateOrder
{
	BOOL success = YES;

	NSColor *good = [NSColor controlTextColor];
	NSColor *bad = [[NSColor redColor] shadowWithLevel:0.15];

	[firstNameLabel setTextColor:good];
	[lastNameLabel setTextColor:good];
	[address1Label setTextColor:good];
	[cityLabel setTextColor:good];
	[stateLabel setTextColor:good];
	[zipcodeLabel setTextColor:good];
	[emailLabel setTextColor:good];
	[creditCardNumberLabel setTextColor:good];
	[creditCardSecurityCodeLabel setTextColor:good];
	[creditCardExpirationLabel setTextColor:good];

	id value = nil;
	NSError *error = nil;
	PFAddress *billingAddress = [order billingAddress];

	if (!(value = [billingAddress firstName]) && ![billingAddress validateValue:&value forKey:@"firstName" error:nil]) {
		[firstNameLabel setTextColor:bad];
		success = NO;
	}

	if (!(value = [billingAddress lastName]) && ![billingAddress validateValue:&value forKey:@"lastName" error:nil]) {
		[lastNameLabel setTextColor:bad];
		success = NO;
	}

	if (!(value = [billingAddress address1]) && ![billingAddress validateValue:&value forKey:@"address1" error:nil]) {
		[address1Label setTextColor:bad];
		success = NO;
	}

	if (!(value = [billingAddress city]) && ![billingAddress validateValue:&value forKey:@"city" error:nil]) {
		[cityLabel setTextColor:bad];
		success = NO;
	}

	if (!(value = [billingAddress state]) && ![billingAddress validateValue:&value forKey:@"state" error:nil]) {
		[stateLabel setTextColor:bad];
		success = NO;
	}

	if (!(value = [billingAddress zipcode]) && ![billingAddress validateValue:&value forKey:@"zipcode" error:nil]) {
		[zipcodeLabel setTextColor:bad];
		success = NO;
	}

	if (!(value = [billingAddress email]) && ![billingAddress validateValue:&value forKey:@"email" error:nil]) {
		[emailLabel setTextColor:bad];
		success = NO;
	}

	if (!(value = [order creditCardNumber]) || ![order validateValue:&value forKey:@"creditCardNumber" error:nil]) {
		[creditCardNumberLabel setTextColor:bad];
		success = NO;
	}

	if (!(value = [order creditCardSecurityCode]) && ![order validateValue:&value forKey:@"creditCardSecurityCode" error:nil]) {
		[creditCardSecurityCodeLabel setTextColor:bad];
		success = NO;
	}

	if (![order validateCreditCardExpiration:&error]) {
		[creditCardExpirationLabel setTextColor:bad];
		success = NO;

		if (error) {
			NSAlert *alert = [NSAlert alertWithError:error];
			[alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:nil contextInfo:NULL];
		}
	}

	return success;
}

@end