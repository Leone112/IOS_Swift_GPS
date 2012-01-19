#import "ControlCell.h"

#import <UIKit/UIControl.h>
#import <UIKit/UILabel.h>

@implementation ControlCell
@synthesize control;
@synthesize controlClass;
@synthesize controlBlock;

- (id) initWithStyle:(UITableViewCellStyle) style reuseIdentifier:(NSString *) reuseIdentifier {
	if (!(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]))
		return nil;

	self.selectionStyle = UITableViewCellSelectionStyleNone;

	return self;
}

- (void) dealloc {
	[control release];

	[super dealloc];
}

#pragma mark -

- (void) setControlClass:(Class) newControlClass {
	controlClass = newControlClass;

	id old = control;
	control = [[controlClass alloc] initWithFrame:CGRectZero];
	[old release];

	[(UIControl *)control addTarget:self action:@selector(valueChanged:) forControlEvents:UIControlEventValueChanged];

	[self.contentView addSubview:control];
}

- (void) setEnabled:(BOOL) enabled
{
	[control setEnabled:enabled];
}

#pragma mark -

- (void) valueChanged:(id) sender
{
	if (controlBlock)
	{
		controlBlock(self);
	}
}

#pragma mark -

- (void) prepareForReuse {
	[super prepareForReuse];

	self.textLabel.text = @"";

	[control removeFromSuperview];
	[control release], control = nil;

	controlClass = NULL;

	if (controlBlock)
	{
		Block_release(controlBlock);
	}
}

- (void) layoutSubviews {
	[super layoutSubviews];

	UIView *controlView = (UIView *)control;
	CGSize controlSize = controlView.frame.size;
	CGRect contentRect = self.contentView.frame;

	UILabel *label = self.textLabel;

	CGRect frame = label.frame;
	frame.size.width = contentRect.size.width - controlSize.width - 30.;
	label.frame = frame;

	frame = controlView.frame;
	frame.origin.y = round((contentRect.size.height / 2.) - (controlSize.height / 2.));
	frame.origin.x = contentRect.size.width - controlSize.width - 10.;
	controlView.frame = frame;
}
@end
