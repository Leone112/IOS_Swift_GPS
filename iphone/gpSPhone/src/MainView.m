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
+ (MainView *)mainView {
	return sharedInstance;
}
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
		[ savedBrowser reloadData ];

		[ recentBrowser setRecent:YES ];
		[ recentBrowser reloadData ];

		[ bookmarkBrowser setBookmarks:YES ];
		[ bookmarkBrowser reloadData ];

		[ self addSubview:navBar ];

		[ self addSubview:transitionView ];
		[ transitionView transition:1 toView:[fileBrowser view] ];

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
					currentView = CUR_BROWSER;
					[ self addSubview:tabBar ];
					if (currentBrowserPage == CB_NORMAL)
						[ transitionView transition:2 toView:[fileBrowser view] ];
					else if (currentBrowserPage == CB_SAVED)
						[ transitionView transition:2 toView:[savedBrowser view] ];
					else if (currentBrowserPage == CB_RECENT)
					{
						[ recentBrowser reloadData ];
						[ transitionView transition:2 toView:[recentBrowser view] ];
					}
					else if (currentBrowserPage == CB_BOOKMARKS)
					{
						[ bookmarkBrowser reloadData ];
						[ transitionView transition:2 toView:[bookmarkBrowser view] ];
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
						[ transitionView transition:2 toView:[fileBrowser view] ];
					else if (currentBrowserPage == CB_SAVED)
						[ transitionView transition:2 toView:[savedBrowser view] ];
					else if (currentBrowserPage == CB_RECENT)
					{
						[ recentBrowser reloadData ];
						[ transitionView transition:2 toView:[recentBrowser view] ];
					}
					else if (currentBrowserPage == CB_BOOKMARKS)
					{
						[ bookmarkBrowser reloadData ];
						[ transitionView transition:2 toView:[bookmarkBrowser view] ];
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
			[ savedBrowser reloadData ];
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
			[ navBar showButtonsWithLeftTitle:@"Back" rightTitle:nil leftBack:YES ];
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
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	[ browser setPath:[ paths objectAtIndex:0 ] ];

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

	[ fileBrowser reloadData ];
	[ savedBrowser reloadData ];
}

#pragma mark -

- (UITabBar *) createTabBar
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
			[ transitionView transition:0 toView:[fileBrowser view] ];
			currentBrowserPage = CB_NORMAL;
			break;
		case 2:
			[ transitionView transition:0 toView:[savedBrowser view] ];
			currentBrowserPage = CB_SAVED;
			break;
		case 3:
			[ bookmarkBrowser reloadData ];
			[ transitionView transition:0 toView:[bookmarkBrowser view] ];
			currentBrowserPage = CB_BOOKMARKS;
			break;
		case 4:
			[ recentBrowser reloadData ];
			[ transitionView transition:0 toView:[recentBrowser view] ];
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

	return 0;
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
					cell.controlBlock = ^(UISwitch *switchControl) {
						preferences.autoSave = switchControl.on;

						gpSPhone_SavePreferences();
					};

					[cell.control setOn:preferences.autoSave];
					break;
				case (1):
					cell.textLabel.text = @"Landscape View";
					cell.controlClass = [UISwitch class];
					cell.controlBlock = ^(UISwitch *switchControl) {
						preferences.landscape = switchControl.on;

						gpSPhone_SavePreferences();
					};

					[cell.control setOn:preferences.landscape];
					break;
				case (2):
					cell.textLabel.text = @"Mute Sound";
					cell.controlClass = [UISwitch class];
					cell.controlBlock = ^(UISwitch *switchControl) {
						preferences.muted = switchControl.on;

						gpSPhone_SavePreferences();
					};

					[cell.control setOn:preferences.muted];
					break;
				case (3):
					cell.textLabel.text = @"Volume Percent";
					cell.controlClass = [UISegmentedControl class];
					cell.controlBlock = ^(UISegmentedControl *segmentedControl) {
						preferences.volume = segmentedControl.selectedSegmentIndex;

						gpSPhone_SavePreferences();
					};

					UISegmentedControl *control = (UISegmentedControl *)cell.control;
					[control insertSegmentWithTitle:@"10" atIndex:0 animated:NO ];
					[control insertSegmentWithTitle:@"20" atIndex:1 animated:NO ];
					[control insertSegmentWithTitle:@"40" atIndex:2 animated:NO ];
					[control insertSegmentWithTitle:@"60" atIndex:3 animated:NO ];
					[control insertSegmentWithTitle:@"80" atIndex:4 animated:NO ];
					[control insertSegmentWithTitle:@"100" atIndex:5 animated:NO ];

					[control setSelectedSegmentIndex:preferences.volume ];
					break;
			}
			break;

		case (1):
			switch (indexPath.row)
			{
				case (0):
					cell.textLabel.text = @"Frame Skip";
					cell.controlClass = [UISegmentedControl class];
					cell.controlBlock = ^(UISegmentedControl *segmentedControl) {
						preferences.frameSkip = segmentedControl.selectedSegmentIndex;

						gpSPhone_SavePreferences();
					};

					UISegmentedControl *control = (UISegmentedControl *)cell.control;
					[control insertSegmentWithTitle:@"0" atIndex:0 animated:NO ];
					[control insertSegmentWithTitle:@"1" atIndex:1 animated:NO ];
					[control insertSegmentWithTitle:@"2" atIndex:2 animated:NO ];
					[control insertSegmentWithTitle:@"3" atIndex:3 animated:NO ];
					[control insertSegmentWithTitle:@"4" atIndex:4 animated:NO ];
					[control insertSegmentWithTitle:@"A" atIndex:5 animated:NO ];

					[control setSelectedSegmentIndex:preferences.frameSkip ];
					break;
				case (1):
					cell.textLabel.text = @"Can Delete ROMs";
					cell.controlClass = [UISwitch class];
					cell.controlBlock = ^(UISwitch *switchControl) {
						preferences.canDeleteROMs = switchControl.on;

						gpSPhone_SavePreferences();
					};

					[cell.control setOn:preferences.canDeleteROMs];
					break;
				case (2):
					cell.textLabel.text = @"Selected Skin";
					cell.controlClass = [UISegmentedControl class];
					cell.controlBlock = ^(UISegmentedControl *segmentedControl) {
						preferences.selectedSkin = segmentedControl.selectedSegmentIndex;

						gpSPhone_SavePreferences();
					};

					control = (UISegmentedControl *)cell.control;
					for (NSUInteger i = 0; i < 6; i++)
						[control insertSegmentWithTitle:[NSString stringWithFormat:@"%d", i] atIndex:i animated:NO];

					[control setSelectedSegmentIndex:preferences.selectedSkin ];
					break;
				case (3):
					cell.textLabel.text = @"Enable Scaling";
					cell.controlClass = [UISwitch class];
					cell.controlBlock = ^(UISwitch *switchControl) {
						preferences.scaled = switchControl.on;

						gpSPhone_SavePreferences();
					};

					[cell.control setOn:preferences.scaled];
					break;
				case (4):
					cell.textLabel.text = @"Enable Cheating";
					cell.controlClass = [UISwitch class];
					cell.controlBlock = ^(UISwitch *switchControl) {
						preferences.cheating = switchControl.on;

						gpSPhone_SavePreferences();
					};

					[cell.control setOn:preferences.cheating];
					break;
				case (5):
					cell.textLabel.text = @"Enable Cheat 1";
					cell.controlClass = [UISwitch class];
					cell.controlBlock = ^(UISwitch *switchControl) {
						preferences.cheat1 = switchControl.on;

						gpSPhone_SavePreferences();
					};

					[cell.control setOn:preferences.cheat1];
					break;
				case (6):
					cell.textLabel.text = @"Enable Cheat 2";
					cell.controlClass = [UISwitch class];
					cell.controlBlock = ^(UISwitch *switchControl) {
						preferences.cheat2 = switchControl.on;

						gpSPhone_SavePreferences();
					};

					[cell.control setOn:preferences.cheat2];
					break;
				case (7):
					cell.textLabel.text = @"Enable Cheat 3";
					cell.controlClass = [UISwitch class];
					cell.controlBlock = ^(UISwitch *switchControl) {
						preferences.cheat3 = switchControl.on;

						gpSPhone_SavePreferences();
					};

					[cell.control setOn:preferences.cheat3];
					break;
				case (8):
					cell.textLabel.text = @"Enable Cheat 4";
					cell.controlClass = [UISwitch class];
					cell.controlBlock = ^(UISwitch *switchControl) {
						preferences.cheat4 = switchControl.on;

						gpSPhone_SavePreferences();
					};

					[cell.control setOn:preferences.cheat4];
					break;
				case (9):
					cell.textLabel.text = @"Enable Cheat 5";
					cell.controlClass = [UISwitch class];
					cell.controlBlock = ^(UISwitch *switchControl) {
						preferences.cheat5 = switchControl.on;

						gpSPhone_SavePreferences();
					};

					[cell.control setOn:preferences.cheat5];
					break;
				case (10):
					cell.textLabel.text = @"Enable Cheat 6";
					cell.controlClass = [UISwitch class];
					cell.controlBlock = ^(UISwitch *switchControl) {
						preferences.cheat6 = switchControl.on;

						gpSPhone_SavePreferences();
					};

					[cell.control setOn:preferences.cheat6];
					break;
				case (11):
					cell.textLabel.text = @"Enable Cheat 7";
					cell.controlClass = [UISwitch class];
					cell.controlBlock = ^(UISwitch *switchControl) {
						preferences.cheat7 = switchControl.on;

						gpSPhone_SavePreferences();
					};

					[cell.control setOn:preferences.cheat7];
					break;
				case (12):
					cell.textLabel.text = @"Enable Cheat 8";
					cell.controlClass = [UISwitch class];
					cell.controlBlock = ^(UISwitch *switchControl) {
						preferences.cheat8 = switchControl.on;

						gpSPhone_SavePreferences();
					};

					[cell.control setOn:preferences.cheat8];
					break;
				case (13):
#ifdef DEBUG
					cell.textLabel.text = @"Debug Mode";
					cell.controlClass = [UISwitch class];
					cell.controlBlock = ^(UISwitch *switchControl) {
						preferences.debug = switchControl.on;

						gpSPhone_SavePreferences();
					};

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
		[ transitionView transition:1 toView:[fileBrowser view] ];
	else if (currentBrowserPage == CB_SAVED)
		[ transitionView transition:1 toView:[savedBrowser view] ];
	else if (currentBrowserPage == CB_RECENT)
	{
		[ recentBrowser reloadData ];
		[ transitionView transition:1 toView:[recentBrowser view] ];
	}
	else if (currentBrowserPage == CB_BOOKMARKS)
	{
		[ bookmarkBrowser reloadData ];
		[ transitionView transition:1 toView:[bookmarkBrowser view] ];
	}

	LOGDEBUG("MainView.gotoMenu() end");
}

@end
