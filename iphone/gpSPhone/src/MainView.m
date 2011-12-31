/*
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; version 2
 * of the License.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 *
 */

#import <UIKit/UIKit.h>

#import "MainView.h"
#import "gpSPhone_iPhone.h"
#import "ControlCell.h"

#import <errno.h>
#import <sys/types.h>
#import <dirent.h>
#import <unistd.h>

char __savefileName[512];
char __lastfileName[512];
char * __fileName;
int __mute;
extern int __emulation_run;
extern char __fileNameTempSave[512];

static MainView * sharedInstance = nil;

void gotoMenu()
{
	[ sharedInstance gotoMenu ];
}

@implementation MainView
- (id) initWithFrame:(struct CGRect)rect
{
	if ((self == [ super initWithFrame:rect ]) != nil)
	{

		sharedInstance = self;

		LOGDEBUG("MainView.initWithFrame()");

		mainRect = rect;
		mainRect = [ UIHardware fullScreenApplicationContentRect ];
		mainRect.origin.x = mainRect.origin.y = 0.0f;

		currentView = CUR_BROWSER;

		navBar = [ self createNavBar ];
		[ self setNavBar ];

		transitionView  = [ self createTransitionView:48 ];
		prefTable       = [ self createPrefPane ];
		fileBrowser     = [ self createBrowser ];
		savedBrowser    = [ self createBrowser ];
		recentBrowser   = [ self createBrowser ];
		bookmarkBrowser = [ self createBrowser ];
		currentBrowserPage = CB_NORMAL;

		if (preferences.canDeleteROMs)
		{
			[ fileBrowser setAllowDeleteROMs:YES ];
			allowDeleteROMs = YES;
		}
		else
		{
			[ fileBrowser setAllowDeleteROMs:NO ];
			allowDeleteROMs = NO;
		}

		[ savedBrowser setSaved:YES ];
		[ savedBrowser reloadData ];

		[ recentBrowser setRecent:YES ];
		[ recentBrowser reloadData ];

		[ bookmarkBrowser setBookmarks:YES ];
		[ bookmarkBrowser reloadData ];


		[ self addSubview:navBar ];

		[ self addSubview:transitionView ];
		[ transitionView transition:1 toView:fileBrowser ];

		buttonBar = [ self createButtonBar ];
		[ self addSubview:buttonBar ];
		LOGDEBUG("MainView.initWithFrame(): Done");
	}

	return self;
}

- (void) dealloc
{
	LOGDEBUG("MainView.dealloc()");
	[ prefTable release ];
	[ navBar release ];
	[ fileBrowser release ];
	[ super dealloc ];
}

#pragma mark -

- (void) alertSheet:(UIAlertSheet *)sheet buttonClicked:(int)button
{
	LOGDEBUG("alertSheet:buttonClicked: %d", button);

	if (sheet == badROMSheet)
	{
		LOGDEBUG("alertSheet:buttonClicked(): badROMSheet");
	}
	else if (sheet == supportSheet)
	{
		if ( button == 1 )
		{
			[UIApp openURL:[NSURL URLWithString:@"http://www.zodttd.com"]];
		}
		else if ( button == 2 )
		{
			[UIApp openURL:[NSURL URLWithString:@"http://www.modmyifone.com/forums/?styleid=3"]];
		}
	}
	else if (sheet == saveStateSheet)
	{
		LOGDEBUG("alertSheet:buttonClicked(): saveStateSheet %d", button);
		if (button == 1)
		{
			if ( (!strcasecmp(__lastfileName + (strlen(__lastfileName) - 4), ".svs")) )
			{
				if ( strcasecmp(__lastfileName, __fileNameTempSave) )
				{
					unlink(__lastfileName);
				}
				rename(__fileNameTempSave, __lastfileName);
			}
			[ savedBrowser reloadData ];
		}
		else if (button == 2)
		{
			[ savedBrowser reloadData ];
		}
		else
		{
			gpSPhone_DeleteTempState();
		}
	}
	else if (sheet == selectROMSheet)
	{
		switch (button)
		{
			case (1):
				[ self load ];
				break;
			case (2):
				if ([ [ m_currentFile pathExtension ] isEqualToString:@"svs" ])
				{
					unlink([ m_currentFile cStringUsingEncoding:
							 NSASCIIStringEncoding ]);
					[ savedBrowser reloadData ];
				}
				else
				{
					if ([ self isBookmarked:m_currentFile ] == NO)
					{
						LOGDEBUG("alertSheet.buttonClicked: calling addBookmark");
						[ self addBookmark:m_currentFile ];
					}
				}
				break;
			case (3):
				if ([ [ m_currentFile pathExtension ] isEqualToString:@"svs" ])
				{
					if ([ self isBookmarked:m_currentFile ] == NO)
					{

						LOGDEBUG("alertSheet.buttonClicked: calling addBookmark (2)");

						[ self addBookmark:m_currentFile ];
					}
				}
				break;
		}
	}

	[ sheet dismiss ];
}

#pragma mark -

- (void) navigationBar:(UINavigationBar *)navbar buttonClicked:(int)button
{
	switch (button)
	{

		/* Left Navigation Button */
		case 1:
			switch (currentView)
			{
				case CUR_PREFERENCES:
					if ([ self savePreferences ] == YES)
					{
						currentView = CUR_BROWSER;
						[ self addSubview:buttonBar ];
						if (currentBrowserPage == CB_NORMAL)
							[ transitionView transition:2 toView:fileBrowser ];
						else if (currentBrowserPage == CB_SAVED)
							[ transitionView transition:2 toView:savedBrowser ];
						else if (currentBrowserPage == CB_RECENT)
						{
							[ recentBrowser reloadData ];
							[ transitionView transition:2 toView:recentBrowser ];
						}
						else if (currentBrowserPage == CB_BOOKMARKS)
						{
							[ bookmarkBrowser reloadData ];
							[ transitionView transition:2 toView:bookmarkBrowser ];
						}
					}
					break;

				case CUR_BROWSER:
					if (currentBrowserPage == CB_RECENT)
					{
						unlink("/var/root/Library/Preferences/gpSPhone.history");
						unlink("/var/mobile/Library/Preferences/gpSPhone.history");
						[ recentBrowser reloadData ];
					}
					break;

				case CUR_EMULATOR:
					[ self stopEmulator:YES];
					currentView = CUR_BROWSER;
					if (currentBrowserPage == CB_NORMAL)
						[ transitionView transition:2 toView:fileBrowser ];
					else if (currentBrowserPage == CB_SAVED)
						[ transitionView transition:2 toView:savedBrowser ];
					else if (currentBrowserPage == CB_RECENT)
					{
						[ recentBrowser reloadData ];
						[ transitionView transition:2 toView:recentBrowser ];
					}
					else if (currentBrowserPage == CB_BOOKMARKS)
					{
						[ bookmarkBrowser reloadData ];
						[ transitionView transition:2 toView:bookmarkBrowser ];
					}
					break;
			}
			break;

		/* Right Navigation Button */
		case 0:
			switch (currentView)
			{
				case CUR_PREFERENCES:
					supportSheet = [ [ UIAlertSheet alloc ] initWithFrame:
									 CGRectMake(0, 240, 320, 240) ];
					[ supportSheet setTitle:@"Support ZodTTD" ];
					[ supportSheet setBodyText:[NSString stringWithFormat:@"Thank you for using my programs for the iPhone and iPod Touch. For more information on my projects head to zodttd.com. Also be sure to visit modmyifone.com for up to date news and a large community of iPhone and iPod Touch users!"] ];
					[ supportSheet addButtonWithTitle:@"www.zodttd.com" ];
					[ supportSheet addButtonWithTitle:@"www.modmyifone.com" ];
					[ supportSheet addButtonWithTitle:@"Cancel" ];
					[ supportSheet setDelegate:self ];
					[ supportSheet presentSheetInView:self ];
					break;
				case CUR_BROWSER:
					currentView = CUR_PREFERENCES;
					[ buttonBar removeFromSuperview ];
					[ transitionView transition:1 toView:prefTable ];
					break;

				case CUR_EMULATOR:
					if (!__mute)
					{
						__mute = 1;
						gpSPhone_MuteSound();
					}
					else
					{
						__mute = 0;
						gpSPhone_DemuteSound();
					}
			}
			break;
	}

	[ self setNavBar ];
}

#pragma mark -

- (void) fileBrowser:(FileBrowser *)browser fileSelected:(NSString *)file
{
	m_currentFile = [ file copy ];
	BOOL bookmarked = [ self isBookmarked:file ];

	selectROMSheet = [ [ UIAlertSheet alloc ] initWithFrame:
					   CGRectMake(0, 240, 320, 240) ];
	[ selectROMSheet setTitle:[ file lastPathComponent ] ];
	[ selectROMSheet setBodyText:@"Please select an action:" ];
	if ([ [ file pathExtension ] isEqualToString:@"svs" ])
	{
		[ selectROMSheet addButtonWithTitle:@"Restore Saved Game" ];
		[ selectROMSheet addButtonWithTitle:@"Delete Saved Game" ];
	}
	else
	{
		[ selectROMSheet addButtonWithTitle:@"Start New Game" ];
	}

	if (bookmarked == NO)
		[ selectROMSheet addButtonWithTitle:@"Bookmark" ];

	[ selectROMSheet addButtonWithTitle:@"Cancel" ];
	[ selectROMSheet setDelegate:self ];
	[ selectROMSheet presentSheetInView:self ];
}

#pragma mark -

- (BOOL) isBookmarked:(NSString *)file
{
	char cFileName[256];
	char buff[1024];
	FILE * in;
	BOOL isBookmarked = NO;
	char * s, * t, * u;

	strlcpy(cFileName,
			[ file cStringUsingEncoding:NSASCIIStringEncoding ],
			sizeof(cFileName));

	t = strdup(cFileName);
	s = strtok(t, "/");
	while (s)
	{
		u = s;
		s = strtok(NULL, "/");
	}

	LOGDEBUG("isBookmarked: checking %s", u);

	in = fopen_home("Library/Preferences/gpSPhone.bookmarks", "r");
	if (in)
	{
		while ((fgets(buff, sizeof(buff), in) != NULL))
			if (!strncmp(buff, u, strlen(u)))
				isBookmarked = YES;
		fclose(in);
	}
	return isBookmarked;
}

- (void) addBookmark:(NSString *)file
{
	char cFileName[256];
	FILE * out;

	strlcpy(cFileName,
			[ file cStringUsingEncoding:NSASCIIStringEncoding ],
			sizeof(cFileName));

	LOGDEBUG("Adding bookmark: %s", cFileName);

	out = fopen_home("Library/Preferences/gpSPhone.bookmarks", "a");
	if (out)
	{
		char * s, * t, * u;
		t = strdup(cFileName);
		s = strtok(t, "/");
		while (s)
		{
			u = s;
			s = strtok(NULL, "/");
		}
		fprintf(out, "%s\n", u);
		fclose(out);
		free(t);
	}
	[ bookmarkBrowser reloadData ];
}

#pragma mark -

- (void) load
{
	int err;
	NSString * file = [ m_currentFile copy ];
	char cFileName[256];

	strlcpy(cFileName,
			[ file cStringUsingEncoding:NSASCIIStringEncoding ],
			sizeof(cFileName));

	LOGDEBUG("MainView.fileBrowser.fileSelected('%s')", cFileName);

	[ UIHardware _setStatusBarHeight:0.0f ];
	[ UIApp setStatusBarMode:2 duration:0 ];

	mainRect = [ UIHardware fullScreenApplicationContentRect ];
	mainRect.origin.x = mainRect.origin.y = 0.0f;
	[ parentWindow setFrame:[ UIHardware fullScreenApplicationContentRect ] ];
	[ self setFrame:mainRect ];
	[ emuView removeFromSuperview ];
	[ emuView release ];
	emuView = [ self createEmulationView ];

	[ transitionView removeFromSuperview ];
	[ transitionView release ];
	transitionView  = [ self createTransitionView:0 ];
	[ self addSubview:transitionView ];

	err = [ emuView loadROM:file ];
	if (!err)
	{
		FILE * in, * out;
		__fileName = strdup(cFileName);
		sprintf(__lastfileName, "%s", __fileName);
		[ prefTable release ];
		prefTable    = [ self createPrefPane ];

		/* Prepend to most recent log */
		in = fopen_home("Library/Preferences/gpSPhone.history", "r");
		out = fopen("/tmp/gpSPhone.history", "w");
		if (out)
		{
			char * s, * t, * u;
			t = strdup(cFileName);
			s = strtok(t, "/");
			while (s)
			{
				u = s;
				s = strtok(NULL, "/");
			}
			fprintf(out, "%s\n", u);
			if (in)
			{
				char buff[1024];
				int total = 1;
				while (total != 25 && (fgets(buff, sizeof(buff), in)) != NULL)
				{
					if (strncmp(buff, u, strlen(u)))
					{
						fprintf(out, "%s", buff);
						total++;
					}
				}
				fclose(in);
			}
			fclose(out);
			rename("/tmp/gpSPhone.history", "/var/mobile/Library/Preferences/gpSPhone.history");
			rename("/tmp/gpSPhone.history", "/var/root/Library/Preferences/gpSPhone.history");
			free(t);
		}

		currentView = CUR_EMULATOR;
		[ transitionView transition:1 toView:emuView ];
		[ self startEmulator ];
	}
	else
	{
		badROMSheet = [ [ UIAlertSheet alloc ] initWithFrame:
						CGRectMake(0, 240, 320, 240) ];
		[ badROMSheet setTitle:@"Unable to load ROM Image" ];
		[ badROMSheet setBodyText:[NSString stringWithFormat:@"Unable to load ROM image %@. It may not be a valid ROM image, or the resources may not be available to load it.", file] ];
		[ badROMSheet addButtonWithTitle:@"OK" ];
		[ badROMSheet setDelegate:self ];
		[ badROMSheet presentSheetInView:self ];
	}
}

#pragma mark -

- (void) startEmulator
{
	LOGDEBUG("MainView.startEmulator()");

	__emulation_run = 1;

	[ UIApp addStatusBarImageNamed:@"NES" removeOnAbnormalExit:YES ];
	pthread_create(&emulation_tid, NULL, gpSPhone_Thread_Start, NULL);
	LOGDEBUG("MainView.startEmulator(): Done");

	[ navBar removeFromSuperview ];
	[ buttonBar removeFromSuperview ];
}

- (void) stopEmulator:(BOOL)promptForSave
{

	LOGDEBUG("MainView.stopEmulator()");
	if (currentView != CUR_EMULATOR)
		return;

	if (__emulation_run != 0)
	{
		gpSPhone_Halt();

		LOGDEBUG("MainView.stopEmulator(): calling pthread_join()");
		pthread_join(emulation_tid, NULL);
		LOGDEBUG("MainView.stopEmulator(): pthread_join() returned");
	}

	[ UIApp removeStatusBarImageNamed:@"NES" ];

	LOGDEBUG("MainView.stopEmulator(): saving SRAM");

	if (promptForSave == YES)
	{
		if (preferences.autoSave)
		{
			[ savedBrowser reloadData ];
		}
		else
		{
			saveStateSheet = [ [ UIAlertSheet alloc ] initWithFrame:
							   CGRectMake(0, 240, 320, 240) ];
			[ saveStateSheet setTitle:@"Do you want to save this game?" ];
			[ saveStateSheet setBodyText:@"Do you want to create a new save state or overwrite the currently loaded save?" ];
			[ saveStateSheet addButtonWithTitle:@"Yes Overwrite Current" ];
			[ saveStateSheet addButtonWithTitle:@"Yes" ];
			[ saveStateSheet addButtonWithTitle:@"No" ];
			[ saveStateSheet setDelegate:self ];
			[ saveStateSheet presentSheetInView:self ];
		}
	}
	else
	{
		gpSPhone_DeleteTempState();
	}

	LOGDEBUG("MainView.stopEmulator(): Done");
}

- (void) suspendEmulator
{
	if (currentView != CUR_EMULATOR)
		return;
	// Main_Halt();
	currentView = CUR_EMULATOR_SUSPEND;
	LOGDEBUG("MainView.suspendEmulator(): calling pthread_join()");
	// pthread_join(emulation_tid, NULL);
	LOGDEBUG("MainView.suspendEmulator(): pthread_join() returned");
}

- (void) resumeEmulator
{
	if (currentView != CUR_EMULATOR_SUSPEND)
		return;

	currentView = CUR_EMULATOR;

	// Main_Resume();
	// __emulation_run = 1;
	// pthread_create(&emulation_tid, NULL, Main_Thread_Start, NULL);
}

#pragma mark -

- (void) setNavBar
{
	switch (currentView)
	{

		case (CUR_PREFERENCES):
			[ navItem setTitle:@"Settings" ];
			[ navBar showButtonsWithLeftTitle:@"Back"
								   rightTitle:@"Support" leftBack:YES
			];
			break;

		case (CUR_BROWSER):
			if (currentBrowserPage != CB_RECENT)
			{
				[navBar showButtonsWithLeftTitle:nil
									  rightTitle:@"Settings" leftBack:NO
				];
			}
			else
			{
				[navBar showButtonsWithLeftTitle:@"Clear"
									  rightTitle:@"Settings" leftBack:NO
				];
			}

			switch (currentBrowserPage)
			{
				case (CB_NORMAL):
					[ navItem setTitle:@"All Games" ];
					break;
				case (CB_SAVED):
					[ navItem setTitle:@"Saved Games" ];
					break;
				case (CB_RECENT):
					[ navItem setTitle:@"Most Recent" ];
					break;
				case (CB_BOOKMARKS):
					[ navItem setTitle:@"Bookmarks" ];
					break;
			}

			break;

		case (CUR_EMULATOR):
			[ navItem setTitle:@"" ];
			if (!__mute)
			{
				[navBar showLeftButton:@"ROM List" withStyle:2
						   rightButton:@"Mute" withStyle:0 ];
			}
			else
			{
				[navBar showLeftButton:@"ROM List" withStyle:2
						   rightButton:@"Mute" withStyle:1 ];
			}
			break;
	}
}

#pragma mark -

- (FileBrowser *) createBrowser
{
	float offset = 48.0 * 2; /* nav bar + button bar */

	LOGDEBUG("MainView.createBrowser(): Initializing");
	FileBrowser * browser = [ [ FileBrowser alloc ] init];

	[ browser setSaved:NO ];

	/* Determine which ROM path */
	DIR * testdir;
	testdir = opendir(ROM_PATH2);
	if (testdir != NULL)
	{
		[ browser setPath:@ROM_PATH2 ];
	}
	else
	{
		[ browser setPath:@ROM_PATH1 ];
	}
	[ browser setDelegate:self ];
	[ browser setAllowDeleteROMs:allowDeleteROMs ];

	return browser;
}

- (EmulationView *) createEmulationView
{
	EmulationView * emu = [ [ EmulationView alloc ]
							initWithFrame:
							CGRectMake(0, 0, mainRect.size.width, mainRect.size.height)
		];

	return emu;
}

- (UINavigationBar *) createNavBar
{
	UINavigationBar * nav = [ [ UINavigationBar alloc ] initWithFrame:
							  CGRectMake(0, 0, mainRect.size.width, 48.0f)
		];

	[ nav setDelegate:self ];
	[ nav enableAnimation ];

	navItem = [[UINavigationItem alloc] initWithTitle:@""];
	[ nav pushNavigationItem:navItem ];

	return nav;
}

- (UITransitionView *) createTransitionView:(int)offset
{
	UITransitionView * transition = [ [ UITransitionView alloc ]
									  initWithFrame:
									  CGRectMake(mainRect.origin.x, mainRect.origin.y + offset, mainRect.size.width,
												 mainRect.size.height - offset)
		];

	return transition;
}

#pragma mark -

- (BOOL) isBrowsing
{
	return (currentView != CUR_EMULATOR)
}

- (void) reloadBrowser
{
	LOGDEBUG("MainView.reloadBrowser()");
	if (currentBrowserPage == CB_NORMAL)
		[ fileBrowser scrollToTop ];
	else
		[ savedBrowser scrollToTop ];

	[ fileBrowser reloadData ];
	[ savedBrowser reloadData ];
}

#pragma mark -

- (BOOL) savePreferences
{
	BOOL ret = YES;

	LOGDEBUG("savePreferences: currentView %d", currentView);

	if (currentView != CUR_PREFERENCES)
		return YES;

	preferences.frameSkip = [ frameControl selectedSegment ];
	preferences.volume = [ volumeControl selectedSegment ];
	preferences.selectedSkin = [ skinControl selectedSegment ];

#ifdef DEBUG
	IS_DEBUG = [ debugControl value ];
	if (IS_DEBUG != preferences.debug)
	{
		EmulationView * _newEmuView = [ self createEmulationView ];
		[emuView release];
		emuView = _newEmuView;
	}
	preferences.debug = IS_DEBUG;
#else
	preferences.debug = 0;
	IS_DEBUG = 0;
#endif

	preferences.canDeleteROMs   = [ delromsControl value ];
	if (preferences.canDeleteROMs)
	{
		[ fileBrowser setAllowDeleteROMs:YES ];
		allowDeleteROMs = YES;
	}
	else
	{
		[ fileBrowser setAllowDeleteROMs:NO ];
		allowDeleteROMs = NO;
	}

	preferences.autoSave        = [ autosaveControl value ];
	preferences.landscape       = [ landscapeControl value ];
	preferences.muted           = [ mutedControl value ];
	preferences.scaled          = [ scaledControl value ];
	preferences.cheating        = [ cheatControl value ];
	preferences.cheat1          = [ cheat1Control value ];
	preferences.cheat2          = [ cheat2Control value ];
	preferences.cheat3          = [ cheat3Control value ];
	preferences.cheat4          = [ cheat4Control value ];
	preferences.cheat5          = [ cheat5Control value ];
	preferences.cheat6          = [ cheat6Control value ];
	preferences.cheat7          = [ cheat7Control value ];
	preferences.cheat8          = [ cheat8Control value ];

	gpSPhone_SavePreferences();

	return ret;
}

- (UIButtonBar *) createButtonBar
{
	UIButtonBar * bar;

	bar = [ [ UIButtonBar alloc ]
			  initInView:self
			   withFrame:CGRectMake(0.0f, 431.0f, 320.0f, 49.0f)
			withItemList:[ self buttonBarItems ] ];
	[bar setDelegate:self];
	[bar setBarStyle:1];
	[bar setButtonBarTrackingMode:2];

	int buttons[5] = { 1, 2, 3, 4, 5 };
	[bar registerButtonGroup:0 withButtons:buttons withCount:5];
	[bar showButtonGroup:0 withDuration:0.0f];
	int tag;

	for (tag = 1; tag < 5; tag++)
	{
		[ [ bar viewWithTag:tag ]
		  setFrame:CGRectMake(2.0f + ((tag - 1) * 80.0f), 1.0f, 80.0f, 48.0f)
		];
	}
	[ bar showSelectionForButton:1];

	return bar;
}

- (NSArray *) buttonBarItems
{
	return [ NSArray arrayWithObjects:
			 [ NSDictionary dictionaryWithObjectsAndKeys:
			   @"buttonBarItemTapped:", kUIButtonBarButtonAction,
			   @"TopRated.png", kUIButtonBarButtonInfo,
			   @"TopRated.png", kUIButtonBarButtonSelectedInfo,
			   [ NSNumber numberWithInt:1], kUIButtonBarButtonTag,
			   self, kUIButtonBarButtonTarget,
			   @"All Games", kUIButtonBarButtonTitle,
			   @"0", kUIButtonBarButtonType,
			   nil
			 ],

			 [ NSDictionary dictionaryWithObjectsAndKeys:
			   @"buttonBarItemTapped:", kUIButtonBarButtonAction,
			   @"History.png", kUIButtonBarButtonInfo,
			   @"History.png", kUIButtonBarButtonSelectedInfo,
			   [ NSNumber numberWithInt:2], kUIButtonBarButtonTag,
			   self, kUIButtonBarButtonTarget,
			   @"Saved Games", kUIButtonBarButtonTitle,
			   @"0", kUIButtonBarButtonType,
			   nil
			 ],

			 [ NSDictionary dictionaryWithObjectsAndKeys:
			   @"buttonBarItemTapped:", kUIButtonBarButtonAction,
			   @"Bookmarks.png", kUIButtonBarButtonInfo,
			   @"Bookmarks.png", kUIButtonBarButtonSelectedInfo,
			   [ NSNumber numberWithInt:3], kUIButtonBarButtonTag,
			   self, kUIButtonBarButtonTarget,
			   @"Bookmarks", kUIButtonBarButtonTitle,
			   @"0", kUIButtonBarButtonType,
			   nil
			 ],

			 [ NSDictionary dictionaryWithObjectsAndKeys:
			   @"buttonBarItemTapped:", kUIButtonBarButtonAction,
			   @"MostRecent.png", kUIButtonBarButtonInfo,
			   @"MostRecent.png", kUIButtonBarButtonSelectedInfo,
			   [ NSNumber numberWithInt:4], kUIButtonBarButtonTag,
			   self, kUIButtonBarButtonTarget,
			   @"Most Recent", kUIButtonBarButtonTitle,
			   @"0", kUIButtonBarButtonType,
			   nil
			 ],

			 nil
	];
}

- (void) buttonBarItemTapped:(id)sender
{
	int button = [ sender tag ];

	switch (button)
	{
		case 1:
			[ transitionView transition:0 toView:fileBrowser ];
			currentBrowserPage = CB_NORMAL;
			break;
		case 2:
			[ transitionView transition:0 toView:savedBrowser ];
			currentBrowserPage = CB_SAVED;
			break;
		case 3:
			[ bookmarkBrowser reloadData ];
			[ transitionView transition:0 toView:bookmarkBrowser ];
			currentBrowserPage = CB_BOOKMARKS;
			break;
		case 4:
			[ recentBrowser reloadData ];
			[ transitionView transition:0 toView:recentBrowser ];
			currentBrowserPage = CB_RECENT;
			break;
	}
	[ self setNavBar ];
}

- (UITableView *) createPrefPane
{
	float offset = 0.0;

	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	float transparentComponents[4] = { 0, 0, 0, 0 };
	float grayComponents[4] = { 0.85, 0.85, 0.85, 1 };

	CGColorSpaceRef colorShadow = CGColorSpaceCreateDeviceRGB();

	UITableView * pref = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, mainRect.size.width, mainRect.size.height - offset) style:UITableViewStyleGrouped];

	[ pref setDataSource:self ];
	[ pref setDelegate:self ];

	NSString * verString = [ [NSString alloc] initWithCString:VERSION ];
	id old = versionString;
	versionString = [ [ NSString alloc ] initWithFormat:@"Version %@", verString ];
	[ old release ];

	/* Current Game Title */
	{
		char * x, * o;
		if (!__fileName)
		{
			x = "(No Game Selected)";
		}
		else
		{
			char * y;
			x = strdup(__fileName);
			o = x;
			while ((x = strchr(x, '/')))
			{
				y = x + 1;
				x = y;
			}
			x = y;
			x[strlen(x) - 4] = 0;
		}
		currentGameTitle = [[NSString alloc] initWithCString:x];
		if (__fileName)
			free(o);
	}

	[ pref reloadData ];
	return pref;
}

#pragma mark -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	switch (section)
	{
		case (0):
			return 4;
		case (1):
#ifdef DEBUG
			return 15;
#endif
			return 14;
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (section == 0)
	{
		return @"Game Options";
	}
	else if (section == 1)
	{
		return @"Advanced Options";
	}

	return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.row == -1)
	{
		return 40;
	}

	if (indexPath.section == 1)
	{
		switch (indexPath.row)
		{
			case 0:
				return 55;
			case 2:
				return 55;
		}
	}

	return 44.;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	ControlCell * cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
	if (!cell)
	{
		cell = [[[ControlCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"] autorelease];
	}

#ifdef DEBUG
	if (group == 1 && row == 14)
#else
	if (group == 1 && row == 13)
#endif
		[ cell setEnabled:NO ];
	else
		[ cell setEnabled:YES ];

	switch (group)
	{
		case (0):
			switch (row)
			{
				case (0):
					cell.textLabel.text = @"Auto-Save Game";
					cell.controlClass = [UISwitch class];

					[cell.control setOn:preferences.autoSave];
					break;
				case (1):
					cell.textLabel.text = @"Landscape View";
					cell.controlClass = [UISwitch class];

					[cell.control setOn:preferences.landscape];
					break;
				case (2):
					cell.textLabel.text = @"Mute Sound";
					cell.controlClass = [UISwitch class];

					[cell.control setOn:preferences.muted];
					break;
				case (3):
					cell.textLabel.text = @"Volume Percent";
					cell.controlClass = [UISegmentedControl class];

					[cell.control insertSegment:0 withTitle:@"10" animated:NO ];
					[cell.control insertSegment:1 withTitle:@"20" animated:NO ];
					[cell.control insertSegment:2 withTitle:@"40" animated:NO ];
					[cell.control insertSegment:3 withTitle:@"60" animated:NO ];
					[cell.control insertSegment:4 withTitle:@"80" animated:NO ];
					[cell.control insertSegment:5 withTitle:@"100" animated:NO ];

					[cell.control selectSegment:preferences.volume ];
					break;
			}
			break;

		case (1):
			switch (row)
			{
				case (0):
					cell.textLabel.text = @"Frame Skip";
					cell.controlClass = [UISegmentedControl class];

					[cell.control insertSegment:0 withTitle:@"0" animated:NO ];
					[cell.control insertSegment:1 withTitle:@"1" animated:NO ];
					[cell.control insertSegment:2 withTitle:@"2" animated:NO ];
					[cell.control insertSegment:3 withTitle:@"3" animated:NO ];
					[cell.control insertSegment:4 withTitle:@"4" animated:NO ];
					[cell.control insertSegment:5 withTitle:@"A" animated:NO ];

					[cell.control selectSegment:preferences.frameSkip ];
					break;
				case (1):
					cell.textLabel.text = @"Can Delete ROMs";
					cell.controlClass = [UISwitch class];

					[cell.control setOn:preferences.canDeleteROMs];
					break;
				case (2):
					cell.textLabel.text = @"Selected Skin";
					cell.controlClass = [UISegmentedControl class];

					[cell.control insertSegment:0 withTitle:@"0" animated:NO ];
					[cell.control insertSegment:1 withTitle:@"1" animated:NO ];
					[cell.control insertSegment:2 withTitle:@"2" animated:NO ];
					[cell.control insertSegment:3 withTitle:@"3" animated:NO ];
					[cell.control insertSegment:4 withTitle:@"4" animated:NO ];
					[cell.control insertSegment:5 withTitle:@"5" animated:NO ];

					[cell.control selectSegment:preferences.selectedSkin ];
					break;
				case (3):
					cell.textLabel.text = @"Enable Scaling";
					cell.controlClass = [UISwitch class];

					[cell.control setOn:preferences.scaled];
					break;
				case (4):
					cell.textLabel.text = @"Enable Cheating";
					cell.controlClass = [UISwitch class];

					[cell.control setOn:preferences.cheating];
					break;
				case (5):
					cell.textLabel.text = @"Enable Cheat 1";
					cell.controlClass = [UISwitch class];

					[cell.control setOn:preferences.cheat1];
					break;
				case (6):
					cell.textLabel.text = @"Enable Cheat 2";
					cell.controlClass = [UISwitch class];

					[cell.control setOn:preferences.cheat2];
					break;
				case (7):
					cell.textLabel.text = @"Enable Cheat 3";
					cell.controlClass = [UISwitch class];

					[cell.control setOn:preferences.cheat3];
					break;
				case (8):
					cell.textLabel.text = @"Enable Cheat 4";
					cell.controlClass = [UISwitch class];

					[cell.control setOn:preferences.cheat4];
					break;
				case (9):
					cell.textLabel.text = @"Enable Cheat 5";
					cell.controlClass = [UISwitch class];

					[cell.control setOn:preferences.cheat5];
					break;
				case (10):
					cell.textLabel.text = @"Enable Cheat 6";
					cell.controlClass = [UISwitch class];

					[cell.control setOn:preferences.cheat6];
					break;
				case (11):
					cell.textLabel.text = @"Enable Cheat 7";
					cell.controlClass = [UISwitch class];

					[cell.control setOn:preferences.cheat7];
					break;
				case (12):
					cell.textLabel.text = @"Enable Cheat 8";
					cell.controlClass = [UISwitch class];

					[cell.control setOn:preferences.cheat8];
					break;
				case (13):
#ifdef DEBUG
					cell.textLabel.text = @"Debug Mode";
					cell.controlClass = [UISwitch class];

					[cell.control setOn:preferences.debug];
#else
					cell.textLabel.text = versionString
#endif
					break;
				case (14):
					cell.textLabel.text = versionString
					break;
			}
			break;
	}

	return cell;
}

#pragma mark -

- (int) getCurrentView
{
	return currentView;
}

- (void) reloadButtonBar
{
	[ buttonBar removeFromSuperview ];
	[ buttonBar release ], buttonBar = nil;
	buttonBar = [ self createButtonBar ];
}

- (void) gotoMenu
{
	LOGDEBUG("MainView.gotoMenu()");
	[ self stopEmulator:YES];
	currentView = CUR_BROWSER;

	LOGDEBUG("MainView.gotoMenu() transition");
	[ transitionView removeFromSuperview ];
	[ transitionView release ];
	transitionView = [ self createTransitionView:48 ];
	[ self addSubview:transitionView ];

	LOGDEBUG("MainView.gotoMenu() transition end");

	[ self addSubview:buttonBar ];

	[ self addSubview:navBar ];
	[ self setNavBar ];

	LOGDEBUG("MainView.gotoMenu() set navbar");

	if (currentBrowserPage == CB_NORMAL)
		[ transitionView transition:1 toView:fileBrowser ];
	else if (currentBrowserPage == CB_SAVED)
		[ transitionView transition:1 toView:savedBrowser ];
	else if (currentBrowserPage == CB_RECENT)
	{
		[ recentBrowser reloadData ];
		[ transitionView transition:1 toView:recentBrowser ];
	}
	else if (currentBrowserPage == CB_BOOKMARKS)
	{
		[ bookmarkBrowser reloadData ];
		[ transitionView transition:1 toView:bookmarkBrowser ];
	}

	LOGDEBUG("MainView.gotoMenu() end");
}

@end
