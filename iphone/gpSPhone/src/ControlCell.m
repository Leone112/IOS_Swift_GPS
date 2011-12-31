#import "SegmentedCell.h"

@implementation SegmentedCell
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
@synthesize controlClass;

- (void) setControlClass:(Class) newControlClass {
	NSAssert([controlClass isKindOfClass:[UIControl class]], @"Control class must be a subclass of UIControl");

	controlClass = newControlClass;

	control = [[controlClass alloc] initWithFrame:CGRectZero];

	[self.contentView addSubview:control];
}

- (SEL) controlAction {
	NSArray *actions = [control actionsForTarget:nil forControlEvent:UIControlEventValueChanged];
	if (!actions.count)
		return NULL;
	return NSSelectorFromString([actions objectAtIndex:0]);
}

- (void) setControlAction:(SEL) action {
	[control removeTarget:nil action:NULL forControlEvents:UIControlEventValueChanged];
	[control addTarget:nil action:action forControlEvents:UIControlEventValueChanged];
}

#pragma mark -

- (void) prepareForReuse {
	[super prepareForReuse];

	self.textLabel.text = @"";

	[control removeFromSuperview];
	[control release], control = nil;

	controlClass = NULL;
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
