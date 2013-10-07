

#import "PDFFormTextField.h"
#import <QuartzCore/QuartzCore.h>
#import "PDFView.h"

@implementation PDFFormTextField


-(void)dealloc
{
     [textFieldOrTextView release];
     [super dealloc];
}

-(id)initWithFrame:(CGRect)frame Multiline:(BOOL)multiline Alignment:(UITextAlignment)alignment SecureEntry:(BOOL)secureEntry ReadOnly:(BOOL)ro
{
    self = [super initWithFrame:frame];
    if (self) {
        
        self.opaque = NO;
        self.backgroundColor = ro?[UIColor clearColor]:[UIColor colorWithRed:0.7 green:0.7 blue:1.0 alpha:0.7];
        self.layer.cornerRadius = 4;
        multi = multiline;
        
        Class textCls = multiline?[UITextView class]:[UITextField class];
        textFieldOrTextView = [[textCls alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];    
        if(secureEntry)
        {
            ((UITextField*)textFieldOrTextView).secureTextEntry = YES;
        }
        
        if(ro)
        {
            textFieldOrTextView.userInteractionEnabled = NO;
        }
    
        if(multiline)
        {
            ((UITextView*)textFieldOrTextView).textAlignment = alignment;
            ((UITextView*)textFieldOrTextView).autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
            ((UITextView*)textFieldOrTextView).delegate = self;
            ((UITextView*)textFieldOrTextView).scrollEnabled = NO;
        }
        else 
        {
            ((UITextField*)textFieldOrTextView).textAlignment = alignment;
            ((UITextField*)textFieldOrTextView).delegate = self;
            ((UITextField*)textFieldOrTextView).autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
            [[NSNotificationCenter defaultCenter] 
             addObserver:self 
             selector:@selector(textChanged:)
             name:UITextFieldTextDidChangeNotification 
             object:textFieldOrTextView];
        }
        
        textFieldOrTextView.opaque = NO;
        textFieldOrTextView.backgroundColor = [UIColor clearColor];
        baseFontSize = MAX(MIN(14,frame.size.height*0.6),10);
        fontSize = baseFontSize;
        [textFieldOrTextView performSelector:@selector(setFont:) withObject:[UIFont systemFontOfSize:baseFontSize]];
        [self addSubview:textFieldOrTextView];
    }
    return self;
}

#pragma mark - PDFUIElement

-(void)setValue:(NSString*)value
{
    if([value isKindOfClass:[NSNull class]] == YES)
    {
        [self setValue:nil];
        return;
    }
    [textFieldOrTextView performSelector:@selector(setText:) withObject:value];
    
   if(multi == NO)
   {
       UITextField* textField = (UITextField*)textFieldOrTextView;
       CGFloat factor = [value sizeWithFont:textField.font].width/(textField.bounds.size.width);
       {
           baseFontSize = MAX(MIN(baseFontSize/factor,14),10);
           
           
           fontSize = baseFontSize*zoomScale;
           
           textField.font = [UIFont systemFontOfSize:fontSize];
       }
   }
   [self refresh];
}

-(NSString*)value
{
    NSString* ret = [textFieldOrTextView performSelector:@selector(text)];
    return [ret length]?ret:nil;
}

-(void)updateWithZoom:(CGFloat)zoom
{
    [super updateWithZoom:zoom];
    [textFieldOrTextView performSelector:@selector(setFont:) withObject:[UIFont systemFontOfSize:fontSize=baseFontSize*zoom]];
    [textFieldOrTextView setNeedsDisplay];
    [self setNeedsDisplay];
}

-(void)refresh
{
    [self setNeedsDisplay];
    [textFieldOrTextView setNeedsDisplay];
}

-(void)textChanged:(id)sender
{
    [delegate uiAdditionValueChanged:self];
}

-(void)vectorRenderInPDFContext:(CGContextRef)ctx ForRect:(CGRect)rect 
{
    NSString* text = [(id)textFieldOrTextView text];
    UIFont* font = [UIFont systemFontOfSize:baseFontSize];
    NSTextAlignment align = (NSTextAlignment)[(id)textFieldOrTextView textAlignment];
    UIGraphicsPushContext(ctx);
        CGContextTranslateCTM(ctx, 0, (rect.size.height-baseFontSize)/2);
        [text drawInRect:CGRectMake(0, 0, rect.size.width, rect.size.height) withFont:font lineBreakMode:NSLineBreakByWordWrapping  alignment:align];
    UIGraphicsPopContext();
}

#pragma mark - UITextViewDelegate

-(void)textViewDidBeginEditing:(UITextView*)textView
{
    [delegate uiAdditionEntered:self];
    ((PDFView*)(self.superview.superview.superview)).activeUIAdditionsView = self;
}

-(void)textViewDidEndEditing:(UITextView*)textView{
  
    ((PDFView*)(self.superview.superview.superview)).activeUIAdditionsView = nil;
}

-(void)textViewDidChange:(UITextView*)textView
{
    [delegate uiAdditionValueChanged:self];
}

-(BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    CGSize contentSize = CGSizeMake(textView.bounds.size.width-16, textView.bounds.size.height*2);
    float numLines = ceilf((textView.bounds.size.height / textView.font.lineHeight));
    NSString* newString = [textView.text stringByReplacingCharactersInRange:range withString:text];
    if([newString length] <= [textView.text length])return YES;
    float usedLines = ceilf([newString sizeWithFont:textView.font constrainedToSize:contentSize lineBreakMode:NSLineBreakByWordWrapping].height/textView.font.lineHeight);
    if(usedLines >= numLines && usedLines > 1)return NO;
    return YES;
}

#pragma mark - UITextFieldDelegate


-(BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString* newString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if([newString length] <= [textField.text length])return YES;
    if([newString sizeWithFont:textField.font].width > (textField.bounds.size.width))
    {
        if(baseFontSize > 10)
        {
            baseFontSize = 10;
            fontSize = baseFontSize*zoomScale;
            textField.font = [UIFont systemFontOfSize:fontSize];
            if([newString sizeWithFont:textField.font].width > (textField.bounds.size.width))return NO;
        }
        else return NO;
    }
    return YES;
}

-(void)textFieldDidBeginEditing:(UITextField *)textField
{
    [delegate uiAdditionEntered:self];
     ((PDFView*)(self.superview.superview.superview)).activeUIAdditionsView = self;
}

-(void)textFieldDidEndEditing:(UITextField *)textField
{
    ((PDFView*)(self.superview.superview.superview)).activeUIAdditionsView = nil;
}


-(void)resign
{
    [textFieldOrTextView resignFirstResponder];
}


@end
