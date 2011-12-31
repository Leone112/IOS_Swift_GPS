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

#import "FileBrowser.h"

@implementation FileBrowser
@synthesize path = _path;
@synthesize delegate = _delegate;

- (id) init
{
	if ((self == [super initWithStyle:UITableViewStylePlain]) != nil)
	{
		self.tableView.dataSource = self;
		self.tableView.delegate = self;
		self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;

		_extensions = [[NSMutableArray alloc] init];
		_files = [[NSMutableArray alloc] init];
	}

	return self;
}

- (void) dealloc
{
	_delegate = nil;

	[_path release];
	[_files release];
	[_extensions release];

	[super dealloc];
}

- (NSString *) path
{
	return [[_path copy] autorelease];
}

- (void) setPath:(NSString *)path
{
	id old = _path;
	_path = [path copy];
	[old release];

	[self.tableView reloadData];
}

- (void) addExtension:(NSString *)extension
{
	if (![_extensions containsObject:[extension lowercaseString]])
	{
		[_extensions addObject:[extension lowercaseString]];
	}
}

- (void) setExtensions:(NSArray *)extensions
{
	[_extensions setArray:extensions];
}

- (void) reloadData
{
	NSFileManager * fileManager = [NSFileManager defaultManager];

	if ([fileManager fileExistsAtPath:_path] == NO)
	{
		return;
	}

	[ _files removeAllObjects ];

	if (_recent == NO && _bookmarks == NO)
	{
		NSString * file;
		NSDirectoryEnumerator * dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:_path];
		while ((file = [dirEnum nextObject]))
		{
			char * fn = (char *)[file cStringUsingEncoding:NSASCIIStringEncoding];
			if (_saved)
			{
				if (!strcasecmp(fn + (strlen(fn) - 4), ".svs"))
					[_files addObject:file];
			}
			else
			{
				if (!strcasecmp(fn + (strlen(fn) - 4), ".zip"))
					[_files addObject:file];
				if (!strcasecmp(fn + (strlen(fn) - 4), ".gba"))
					[_files addObject:file];
			}
		}

	}
	else
	{
		FILE * file;
		if (_recent == YES)
		{
			file = fopen_home("Library/Preferences/gpSPhone.history", "r");
		}
		else
		{
			file = fopen_home("Library/Preferences/gpSPhone.bookmarks", "r");
		}
		if (file)
		{
			char buff[1024];
			while ((fgets(buff, sizeof(buff), file)) != NULL)
			{
				buff[strlen(buff) - 1] = 0;
				NSString * string = [ [ NSString alloc ] initWithCString:buff ];
				[ _files addObject:string ];
				[ string release ];
			}
			fclose(file);
		}
	}

	if (_recent == NO)
	{
		NSArray * sorted = [ _files sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:) ];
		[ _files release ];
		_files = [ [ NSMutableArray alloc] initWithArray:sorted ];
	}

	[_table reloadData];
}

- (void) setDelegate:(id)delegate
{
	_delegate = delegate;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [_files count];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	return _allowDeleteROMs;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSString * file = [_path stringByAppendingPathComponent:[_files objectAtIndex:[ _table _rowForTableCell:self]]];
	char * fn = (char *)[file cStringUsingEncoding:NSASCIIStringEncoding];

	LOGDEBUG("UIDeletableCell._willBeDeleted: %s", fn);

	if ((!strcmp(fn + (strlen(fn) - 4), ".svs"))
		|| (!strcasecmp(fn + (strlen(fn) - 4), ".zip"))
		|| (!strcasecmp(fn + (strlen(fn) - 4), ".gba")))
	{
		if ([ _table getBookmarks ] == YES)
			FILE * in, * out;

			in = fopen_home("Library/Preferences/gpSPhone.bookmarks", "r");
			out = fopen("/tmp/gpSPhone.bookmarks", "w");
			if (out)
			{
				char * s, * t, * u;
				t = strdup(file);
				s = strtok(t, "/");
				while (s)
				{
					u = s;
					s = strtok(NULL, "/");
				}
				LOGDEBUG("deleteBookmark: deleting '%s'", u);

				if (in)
				{
					char buff[1024];
					while ((fgets(buff, sizeof(buff), in)) != NULL)
					{
						if (strncmp(buff, u, strlen(u)))
						{
							fprintf(out, "%s", buff);
						}
					}
					fclose(in);
				}
				fclose(out);
				free(t);
				rename("/tmp/gpSPhone.bookmarks", "/var/mobile/Library/Preferences/gpSPhone.bookmarks");
				rename("/tmp/gpSPhone.bookmarks", "/var/root/Library/Preferences/gpSPhone.bookmarks");
			}
		else
			unlink(fn);
	}

	[ _files removeObjectAtIndex:[ _table _rowForTableCell:self ] ];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
	if (!cell)
	{
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"] autorelease];
	}

	cell.textLabel.text = [[_files objectAtIndex:row] stringByDeletingPathExtension ];

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if ( [ _delegate respondsToSelector:@selector( fileBrowser:fileSelected: ) ] )
		[ _delegate fileBrowser:self fileSelected:[ self selectedFile ] ];
}

- (NSString *) selectedFile
{
	if ([_table selectedRow] == -1)
		return nil;

	return [_path stringByAppendingPathComponent:[_files objectAtIndex:[_table selectedRow]]];
}

- (void) setSaved:(BOOL)saved
{
	_saved = saved;
	if (_allowDeleteROMs == NO)
		[ _table allowDelete:saved ];
}

- (void) setRecent:(BOOL)recent
{
	_recent = recent;
	[ _table allowDelete:NO ];
}

- (void) setBookmarks:(BOOL)bookmarks
{
	_bookmarks = bookmarks;
	if (bookmarks == YES)
	{
		[ _table setBookmarks:YES ];
		[ _table allowDelete:YES ];
	}
}

- (BOOL) getSaved
{
	return _saved;
}

- (void) setAllowDeleteROMs:(BOOL)allow
{
	_allowDeleteROMs = allow;
	[ _table allowDelete:allow ];
}

- (void) fileBrowser:(FileBrowser *)browser fileSelected:(NSString *)file
{

}

- (void) scrollToTop
{
	[ _table scrollRowToVisible:0 ];
}

@end
