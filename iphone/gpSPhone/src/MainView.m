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

enum {
	badROMSheetTag,
	saveStateSheetTag,
	selectROMSheetTag,
	supportSheetTag
};

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

@interface UINavigationBar (SPI)
- (void)showButtonsWithLeftTitle:(id)arg1 rightTitle:(id)arg2 leftBack:(BOOL)arg3;
- (void)showLeftButton:(id)arg1 withStyle:(int)arg2 rightButton:(id)arg3 withStyle:(int)arg4;

- (void)pushNavigationItem:(id)arg1;;

- (void)enableAnimation;
@end

@interface MainView (Private)
- (NSArray *) tabBarItems;
@end

@implementation MainView
- (id) initWithFrame:(struct CGRect)rect
{
	if ((self = [ super initWithFrame:rect ]) != nil)
	{

		sharedInstance = self;

		LOGDEBUG("MainView.initWithFrame()");

		mainRect = rect;
		mainRect = [ [ UIScreen mainScreen ] applicationFrame ];
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

		[ fileBrowser setAllowDeleteROMs:preferences.canDeleteROMs ];
		allowDeleteROMs = preferences.canDeleteROMs;

		[ savedBrowser setSaved:YES ];
		[ savedBrowser.tableView reloadData ];

		[ recentBrowser setRecent:YES ];
		[ recentBrowser.tableView reloadData ];

		[ bookmarkBrowser setBookmarks:YES ];
		[ bookmarkBrowser.tableView reloadData ];

		[ self addSubview:navBar ];

		[ self addSubview:transitionView ];
		[ transitionView transition:1 toView:fileBrowser ];

		tabBar = [ self createTabBar ];
		[ self addSubview:tabBar ];
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

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	[self actionSheet:(UIActionSheet *)alertView clickedButtonAtIndex:buttonIndex]; // ugh, ew
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)button
{
	if (sheet.tag == supportSheetTag)
	{
		if ( button == 1 )
		{
			[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.zodttd.com"]];
		}
		else if ( button == 2 )
		{
			[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.modmyifone.com/forums/?styleid=3"]];
		}
	}
	else if (sheet.tag == saveStateSheetTag)
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
			[ savedBrowser.tableView reloadData ];
		}
		else if (button == 2)
		{
			[ savedBrowser.tableView reloadData ];
		}
		else
		{
			gpSPhone_DeleteTempState();
		}
	}
	else if (sheet.tag == selectROMSheetTag)
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
					[ savedBrowser.tableView reloadData ];
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
						[ self addSubview:tabBar ];
						if (currentBrowserPage == CB_NORMAL)
							[ transitionView transition:2 toView:fileBrowser ];
						else if (currentBrowserPage == CB_SAVED)
							[ transitionView transition:2 toView:savedBrowser ];
						else if (currentBrowserPage == CB_RECENT)
						{
							[ recentBrowser.tableView reloadData ];
							[ transitionView transition:2 toView:recentBrowser ];
						}
						else if (currentBrowserPage == CB_BOOKMARKS)
						{
							[ bookmarkBrowser.tableView reloadData ];
							[ transitionView transition:2 toView:bookmarkBrowser ];
						}
					}
					break;

				case CUR_BROWSER:
					if (currentBrowserPage == CB_RECENT)
					{
						unlink("/var/root/Library/Preferences/gpSPhone.history");
						unlink("/var/mobile/Library/Preferences/gpSPhone.history");
						[ recentBrowser.tableView reloadData ];
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
						[ recentBrowser.tableView reloadData ];
						[ transitionView transition:2 toView:recentBrowser ];
					}
					else if (currentBrowserPage == CB_BOOKMARKS)
					{
						[ bookmarkBrowser.tableView reloadData ];
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
					break;
				case CUR_BROWSER:
					currentView = CUR_PREFERENCES;
					[ tabBar removeFromSuperview ];
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

	UIActionSheet *selectROMSheet = [ [ UIActionSheet alloc ] init ];
	[ selectROMSheet setTitle:[NSString stringWithFormat:@"%@\n%@", [ file lastPathComponent ], @"Please select an action:" ] ];
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
	[ selectROMSheet showInView:self ];

	[ selectROMSheet release ];
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
	[ bookmarkBrowser.tableView reloadData ];
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

	[[UIApplication sharedApplication] setStatusBarHidden:YES];

	mainRect = [ [ UIScreen mainScreen ] applicationFrame ];
	mainRect.origin.x = mainRect.origin.y = 0.0f;
	[ parentWindow setFrame:[ [ UIScreen mainScreen ] applicationFrame ] ];
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
		UIActionSheet *badROMSheet = [ [ UIActionSheet alloc ] init];
		[ badROMSheet setTitle:[NSString stringWithFormat:@"Unable to load ROM image %@. It may not be a valid ROM image, or the resources may not be available to load it.", file] ];
		[ badROMSheet addButtonWithTitle:@"OK" ];
		[ badROMSheet setDelegate:self ];
		[ badROMSheet showInView:self ];
		[ badROMSheet release ];
	}
}

#pragma mark -

- (void) startEmulator
{
	LOGDEBUG("MainView.startEmulator()");

	__emulation_run = 1;

	pthread_create(&emulation_tid, NULL, gpSPhone_Thread_Start, NULL);
	LOGDEBUG("MainView.startEmulator(): Done");

	[ navBar removeFromSuperview ];
	[ tabBar removeFromSuperview ];
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

	LOGDEBUG("MainView.stopEmulator(): saving SRAM");

	if (promptForSave == YES)
	{
		if (preferences.autoSave)
		{
			[ savedBrowser.tableView reloadData ];
		}
		else
		{
			UIActionSheet *saveStateSheet = [ [ UIActionSheet alloc ] init ];
			[ saveStateSheet setTitle:@"Do you want to create a new save state or overwrite the currently loaded save?" ];
			[ saveStateSheet addButtonWithTitle:@"Yes Overwrite Current" ];
			[ saveStateSheet addButtonWithTitle:@"Yes" ];
			[ saveStateSheet addButtonWithTitle:@"No" ];
			[ saveStateSheet setDelegate:self ];
			[ saveStateSheet showInView:self ];
			[ saveStateSheet release ];
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
			[ navBar showButtonsWithLeftTitle:@"Back" rightTitle:@"Support" leftBack:YES ];
			break;

		case (CUR_BROWSER):
			if (currentBrowserPage != CB_RECENT)
			{
				[navBar showButtonsWithLeftTitle:nil rightTitle:@"Settings" leftBack:NO ];
			}
			else
			{
				[navBar showButtonsWithLeftTitle:@"Clear" rightTitle:@"Settings" leftBack:NO ];
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
	return (currentView != CUR_EMULATOR);
}

- (void) reloadBrowser
{
	LOGDEBUG("MainView.reloadBrowser()");
	if (currentBrowserPage == CB_NORMAL)
		[ fileBrowser scrollToTop ];
	else
		[ savedBrowser scrollToTop ];

	[ fileBrowser.tableView reloadData ];
	[ savedBrowser.tableView reloadData ];
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

- (UIButtonBar *) createTabBar
{
	UITabBar * bar = [ [ UITabBar alloc ] init ];
	bar.frame = CGRectMake(0.0f, 431.0f, 320.0f, 49.0f);
	bar.items = [ self tabBarItems ];

	[bar setDelegate:self];

	bar.selectedItem = 0;

	return bar;
}

- (NSArray *) tabBarItems
{
	UITabBarItem *allGames = [[[UITabBarItem alloc] initWithTitle:@"All Games" image:[UIImage imageNamed:@"TopRated.png"] tag:1] autorelease];
	UITabBarItem *savedGames = [[[UITabBarItem alloc] initWithTitle:@"Saved Games" image:[UIImage imageNamed:@"History.png"] tag:2] autorelease];
	UITabBarItem *bookmarks = [[[UITabBarItem alloc] initWithTitle:@"Bookmarks" image:[UIImage imageNamed:@"Bookmarks.png"] tag:3] autorelease];
	UITabBarItem *mostRecent = [[[UITabBarItem alloc] initWithTitle:@"Most Recent" image:[UIImage imageNamed:@"MostRecent.png"] tag:4] autorelease];

	return [NSArray arrayWithObjects:allGames, savedGames, bookmarks, mostRecent, nil];
}

- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item
{
	switch ([ item tag ])
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
			[ bookmarkBrowser.tableView reloadData ];
			[ transitionView transition:0 toView:bookmarkBrowser ];
			currentBrowserPage = CB_BOOKMARKS;
			break;
		case 4:
			[ recentBrowser.tableView reloadData ];
			[ transitionView transition:0 toView:recentBrowser ];
			currentBrowserPage = CB_RECENT;
			break;
	}
	[ self setNavBar ];
}

- (UITableView *) createPrefPane
{
	UITableView * pref = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, mainRect.size.width, mainRect.size.height) style:UITableViewStyleGrouped];

	[ pref setDataSource:self ];
	[ pref setDelegate:self ];

	NSString * verString = [ [NSString alloc] initWithCString:VERSION encoding:NSUTF8StringEncoding ];
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
		currentGameTitle = [[NSString alloc] initWithCString:x encoding:NSUTF8StringEncoding ];
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
	if (indexPath.section == 1 && indexPath.row == 14)
#else
	if (indexPath.section == 1 && indexPath.row == 13)
#endif
		[ cell setEnabled:NO ];
	else
		[ cell setEnabled:YES ];

	switch (indexPath.section)
	{
		case (0):
			switch (indexPath.row)
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
			switch (indexPath.row)
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
					cell.textLabel.text = versionString;
#endif
					break;
				case (14):
					cell.textLabel.text = versionString;
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
	[ tabBar removeFromSuperview ];
	[ tabBar release ], tabBar = nil;
	tabBar = [ self createTabBar ];
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

	[ self addSubview:tabBar ];

	[ self addSubview:navBar ];
	[ self setNavBar ];

	LOGDEBUG("MainView.gotoMenu() set navbar");

	if (currentBrowserPage == CB_NORMAL)
		[ transitionView transition:1 toView:fileBrowser ];
	else if (currentBrowserPage == CB_SAVED)
		[ transitionView transition:1 toView:savedBrowser ];
	else if (currentBrowserPage == CB_RECENT)
	{
		[ recentBrowser.tableView reloadData ];
		[ transitionView transition:1 toView:recentBrowser ];
	}
	else if (currentBrowserPage == CB_BOOKMARKS)
	{
		[ bookmarkBrowser.tableView reloadData ];
		[ transitionView transition:1 toView:bookmarkBrowser ];
	}

	LOGDEBUG("MainView.gotoMenu() end");
}

@end
