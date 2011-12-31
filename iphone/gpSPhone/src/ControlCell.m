#import "SegmentedCell.h"

@implementation ControlCell
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

@synthesize control;
@synthesize controlBlock;

- (void) setControlClass:(Class) newControlClass {
	NSAssert([controlClass isKindOfClass:[UIControl class]], @"Control class must be a subclass of UIControl");

	controlClass = newControlClass;

	id old = control;
	control = [[controlClass alloc] initWithFrame:CGRectZero];
	[old release];

	[control addTarget:self action:@selector(valueChanged:) forControlEvent:UIControlEventValueChanged];

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

	CGSize controlhSize = control.frame.size;
	CGRect contentRect = self.contentView.frame;

	UILabel *label = self.textLabel;

	CGRect frame = label.frame;
	frame.size.width = contentRect.size.width - switchSize.width - 30.;
	label.frame = frame;

	frame = control.frame;
	frame.origin.y = round((contentRect.size.height / 2.) - (switchSize.height / 2.));
	frame.origin.x = contentRect.size.width - switchSize.width - 10.;
	control.frame = frame;
}
@end
