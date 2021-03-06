/*
* Copyright (c) 2016, Alcatel-Lucent Inc
* All rights reserved.
*
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are met:
*     * Redistributions of source code must retain the above copyright
*       notice, this list of conditions and the following disclaimer.
*     * Redistributions in binary form must reproduce the above copyright
*       notice, this list of conditions and the following disclaimer in the
*       documentation and/or other materials provided with the distribution.
*     * Neither the name of the copyright holder nor the names of its contributors
*       may be used to endorse or promote products derived from this software without
*       specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
* ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
* DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY
* DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
* (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
* LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
* ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

@import <Foundation/Foundation.j>
@import <AppKit/CPWindowController.j>
@import <AppKit/CPButton.j>
@import <AppKit/CPView.j>
@import <AppKit/CPTableView.j>
@import <AppKit/CPCheckBox.j>

@import <TNKit/TNTableViewDataSource.j>
@import <Bambou/NURESTError.j>
@import <Bambou/NURESTConfirmation.j>
@import "NUUtilities.j"
@import "NUSkin.j"

@class NUKit

@global CPApp
@global NUKitUserLoggedOutNotification
@global NUMainWindowController


var NUMessagesWindowControllerDefault,
    NUMessagesWindowControllerButtonOKOffImage,
    NUMessagesWindowControllerButtonOKOffPressedImage,
    NUMessagesWindowControllerButtonCancelOffImage,
    NUMessagesWindowControllerButtonCancelOffPressedImage;

@implementation NUMessagesWindowController : CPWindowController
{
    @outlet CPButton            buttonCancel;
    @outlet CPButton            buttonCancelAll;
    @outlet CPButton            buttonOK;
    @outlet CPButton            buttonValidateAll;
    @outlet CPCheckBox          checkBoxIgnore;
    @outlet CPTableView         tableViewMessages;

    CPNumber                    _numberOfConfirmations;
    CPView                      _viewBlur;
    TNTableViewDataSource       _dataSourceMessages;
}


#pragma mark -
#pragma mark Class Methods

+ (void)initialize
{
    NUMessagesWindowControllerButtonOKOffImage            = NUImageInKit(@"button-message-checkbox-ok-off.png", 16.0, 16.0);
    NUMessagesWindowControllerButtonOKOffPressedImage     = NUImageInKit(@"button-message-checkbox-ok-off-pressed.png", 16.0, 16.0);
    NUMessagesWindowControllerButtonCancelOffImage        = NUImageInKit(@"button-message-checkbox-cancel-off.png", 16.0, 16.0);
    NUMessagesWindowControllerButtonCancelOffPressedImage = NUImageInKit(@"button-message-checkbox-cancel-off-pressed.png", 16.0, 16.0);
}

+ (id)defaultController
{
    return NUMessagesWindowControllerDefault;
}

#pragma mark -
#pragma mark Initialization

- (id)init
{
    self = [self initWithWindowCibName:@"MessagesWindow"]

    return self;
}

- (void)windowDidLoad
{
    var win = [self window];

    [win setBackgroundColor:NUSkinColorWhite];
    [win setMovableByWindowBackground:YES];
    [win setDefaultButton:buttonOK];
    [win center];

    win._windowView._DOMElement.style.WebkitAnimationName = "scaleIn";
    [win._windowView setBorderRadius:3];
    [win._windowView setBorderColor:NUSkinColorGreyDark];
    win._windowView._DOMElement.style.boxShadow = "0 0 20px " + [NUSkinColorGreyDark cssString];
    win._windowView._DOMElement.style.MozBoxShadow = "0 0 20px " + [NUSkinColorGreyDark cssString];
    win._windowView._DOMElement.style.WebkitBoxShadow = "0 0 20px" + [NUSkinColorGreyDark cssString];

    // table view management
    _dataSourceMessages = [[TNTableViewDataSource alloc] init];
    [_dataSourceMessages setTable:tableViewMessages];
    [tableViewMessages setDataSource:_dataSourceMessages];
    [tableViewMessages setDelegate:self];
    [tableViewMessages setBackgroundColor:NUSkinColorWhite];
    [tableViewMessages setIntercellSpacing:CGSizeMakeZero()];

    // buttons
    [buttonValidateAll setBordered:NO];
    [buttonValidateAll setButtonType:CPMomentaryChangeButton];
    [buttonValidateAll setValue:NUMessagesWindowControllerButtonOKOffImage forThemeAttribute:@"image" inState:CPThemeStateNormal];
    [buttonValidateAll setValue:NUMessagesWindowControllerButtonOKOffPressedImage forThemeAttribute:@"image"inState:CPThemeStateHighlighted];

    [buttonCancelAll setBordered:NO];
    [buttonCancelAll setButtonType:CPMomentaryChangeButton];
    [buttonCancelAll setValue:NUMessagesWindowControllerButtonCancelOffImage forThemeAttribute:@"image" inState:CPThemeStateNormal];
    [buttonCancelAll setValue:NUMessagesWindowControllerButtonCancelOffPressedImage forThemeAttribute:@"image" inState:CPThemeStateHighlighted];

    _viewBlur = [[CPView alloc] initWithFrame:CGRectMakeZero()];
    [_viewBlur setBackgroundColor:[CPColor whiteColor]];
    [_viewBlur setAlphaValue:0.5];
    [_viewBlur setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];

    // TODO: uncomment this lines in few weeks once chrome has been fixed - 24/09/15
    //[_viewBlur setInAnimation:@"fadeInHalf" duration:0.5];
    //[_viewBlur setOutAnimation:@"fadeOutHalf" duration:0.5];
    _viewBlur._DOMElement.style.WebkitBackdropFilter = @"blur(10px)";

    [self window]._windowView._DOMElement.style.borderRadius =  "3px";

    _cucappID(buttonOK, "message-button-ok");
    _cucappID(buttonCancel, "message-button-cancel");
    _cucappID(buttonCancelAll, "message-button-cancel-all");
    _cucappID(buttonValidateAll, "message-button-validate-all");

    [[CPNotificationCenter defaultCenter] addObserver:self selector:@selector(close) name:NUKitUserLoggedOutNotification object:nil];
}

- (id)initWithWindowCibName:(CPString)aName
{
    if (self = [super initWithWindowCibName:aName])
    {
        NUMessagesWindowControllerDefault = self;
        _numberOfConfirmations = 0;
        [self window];
    }

    return self;
}


#pragma mark -
#pragma mark Utilities

- (void)hideBlurView
{
    if (_viewBlur)
        [_viewBlur removeFromSuperview];
}

- (void)pushMessage:(id)aMessage
{
    // @TODO: This is a hack. As server uses "enterprise" terminology
    // we replace all occurences of enterprise by organization

    var name = [aMessage name],
        description = [aMessage description];

    if (name)
        [aMessage setName:[aMessage name].replace(/enterprise/g, "organization").replace(/Enterprise/g, "Organization")];


    if (description)
        [aMessage setDescription:[aMessage description].replace(/enterprise/g, "organization").replace(/Enterprise/g, "Organization")];
    // End of hack

    [_dataSourceMessages addObject:aMessage];
    [tableViewMessages reloadData];

    if ([aMessage isKindOfClass:NURESTConfirmation])
        _numberOfConfirmations++;

    [buttonCancel setHidden:!_numberOfConfirmations];
    [checkBoxIgnore setHidden:_numberOfConfirmations <= 0];

    if (_numberOfConfirmations > 1)
    {
        [buttonCancelAll setHidden:NO];
        [buttonValidateAll setHidden:NO];
    }
    else
    {
        [buttonCancelAll setHidden:YES];
        [buttonValidateAll setHidden:YES];
    }

    if (![[self window] isVisible])
        [self showWindow:nil];
    else
        [self _resize];
}

- (void)_resize
{
    var numberOfMessages = [_dataSourceMessages count],
        frame = [[self window] frame],
        size = frame.size,
        containerSize = [CPPlatform isBrowser] ? [[[self window] platformWindow] contentBounds].size : [[self screen] visibleFrame].size;

    size.height = 89 + (numberOfMessages * 76);

    if (size.height > containerSize.height)
        size.height = containerSize.height;

    if (size.width > containerSize.width)
        size.width = containerSize.width;

    frame.size = size;

    var origin = CGPointMake((containerSize.width - size.width) / 2.0, (containerSize.height - size.height) / 2.0);

    if (origin.x < 0.0)
        origin.x = 0.0;

    if (origin.y < 0.0)
        origin.y = 0.0;

    frame.origin = origin;

    if ([[self window] isVisible])
        [[self window] setFrame:frame display:YES animate:YES];
    else
        [[self window] setFrame:frame];
}


#pragma mark -
#pragma mark Actions

- (@action)showWindow:(id)aSender
{
    [[self window] setPlatformWindow:[[CPApp keyWindow] platformWindow]];

    [tableViewMessages reloadData];
    [checkBoxIgnore setState:CPOffState];

    if (![_viewBlur superview])
    {
        var mainContentView = [[CPApp mainWindow] contentView];
        [_viewBlur setFrame:[mainContentView bounds]];
        [mainContentView addSubview:_viewBlur];
    }

    [self _resize];

    // this will make an eventual popover semi-transient if needed
    // to avoid closing it when user interact with the alert.
    [[NUKit kit] lockCurrentPopover];

    [super showWindow:aSender];
}

- (@action)close:(id)aSender
{
    [_viewBlur removeFromSuperview];
    _numberOfConfirmations = 0;
    [_dataSourceMessages removeAllObjects];

    [self close];

    [[NUKit kit] unlockCurrentPopover];
}

- (@action)cancel:(id)aSender
{
    [self setCancelAllNotification:aSender];
    [self sendReply:self];
}

- (@action)sendReply:(id)aSender
{
    for (var i = 0, c = [_dataSourceMessages count]; i < c; i++)
    {
        var message = [_dataSourceMessages objectAtIndex:i];

        if (![checkBoxIgnore isHidden] && [checkBoxIgnore state] == CPOnState)
            [[message connection] enableAutoConfirm:YES];

        if ([message isKindOfClass:NURESTConfirmation])
            [message confirm];
    }

    [_dataSourceMessages removeAllObjects];

    [self close:nil];
}

- (@action)setValidateAllNotification:(id)aSender
{
    for (var i = 0, c = [_dataSourceMessages count]; i < c; i++)
    {
        var message = [_dataSourceMessages objectAtIndex:i];
        if ([message isKindOfClass:NURESTConfirmation])
            [message setCurrentChoice:1];
    }
}

- (@action)setCancelAllNotification:(id)aSender
{
    for (var i = 0, c = [_dataSourceMessages count]; i < c; i++)
    {
        var message = [_dataSourceMessages objectAtIndex:i];
        if ([message isKindOfClass:NURESTConfirmation])
            [message setCurrentChoice:0];
    }
}


#pragma mark -
#pragma mark Delegates

/*! Table View Delegate
*/
- (int)tableView:(CPTabView)aTableView heightOfRow:(int)aRow
{
    return [[[NUKit kit] registeredDataViewWithIdentifier:@"messageDataView"] frameSize].height;
}

/*! Table View Delegate
*/
- (CPView)tableView:(CPTabView)aTableView viewForTableColumn:(CPTableColumn)aColumn row:(int)aRow
{
    var key = [[_dataSourceMessages objectAtIndex:aRow] className],
        view = [aTableView makeViewWithIdentifier:key owner:self];

    if (!view)
    {
        view = [[[NUKit kit] registeredDataViewWithIdentifier:@"messageDataView"] duplicate];
        [view setIdentifier:key];
    }

    return view;
}


#pragma mark -
#pragma mark Overrides

// TODO: this is insane, I guess Cocoa has a way to specify the bundle instead of overrides these two methos

- (void)loadWindow
{
    if (_window)
        return;

    [[CPBundle bundleWithIdentifier:@"net.nuagenetworks.nukit"] loadCibFile:[self windowCibPath] externalNameTable:@{ CPCibOwner: _cibOwner }];
}

- (CPString)windowCibPath
{
    if (_windowCibPath)
        return _windowCibPath;

    return [[CPBundle bundleWithIdentifier:@"net.nuagenetworks.nukit"] pathForResource:_windowCibName + @".cib"];
}

@end
