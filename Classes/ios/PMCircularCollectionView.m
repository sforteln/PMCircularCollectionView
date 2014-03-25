//
//  PMCircularCollectionView.m
//  
//
//  Created by Peter Meyers on 3/19/14.
//
//

#import "PMCircularCollectionView.h"
#import "PMUtils.h"

static CGFloat const ContentMultiplier = 4.0f;

static inline NSString * PMReuseIdentifierForViewIndex(NSUInteger index) {
    return [[NSNumber numberWithInteger:index] stringValue];
}


@interface PMCircularCollectionView () <UICollectionViewDataSource>

@property (nonatomic) CGSize viewsSize;
@property (nonatomic, strong) CAGradientLayer *shadowLayer;
@property (nonatomic, strong) PMProtocolInterceptor *delegateInterceptor;

@end


@implementation PMCircularCollectionView

- (instancetype) init
{
    return [super initWithFrame:CGRectZero collectionViewLayout:[UICollectionViewFlowLayout new]];
}

- (instancetype) initWithFrame:(CGRect)frame
{
    return [super initWithFrame:frame collectionViewLayout:[UICollectionViewFlowLayout new]];
}

- (instancetype) initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewFlowLayout *)layout
{
    self = [super initWithFrame:frame collectionViewLayout:layout];
    if (self) {
        
        NSSet *protocols = [NSSet setWithObjects:
                            @protocol(UICollectionViewDelegate),
                            @protocol(UIScrollViewDelegate),
                            @protocol(UICollectionViewDelegateFlowLayout), nil];
        
        _delegateInterceptor = [[PMProtocolInterceptor alloc] initWithInterceptedProtocols:protocols];
        _delegateInterceptor.middleMan = self;
        self.delegate = (id)self.delegateInterceptor;
        self.dataSource = self;
        self.showsHorizontalScrollIndicator = NO;
        self.showsVerticalScrollIndicator = NO;
    }
    return self;
}


- (id<UICollectionViewDelegateFlowLayout>) secondaryDelegate
{
    return self.delegateInterceptor.receiver;
}

- (void) setSecondaryDelegate:(id<UICollectionViewDelegateFlowLayout>)secondaryDelegate
{
    self.delegateInterceptor.receiver = secondaryDelegate;
}

- (void) setViews:(NSArray *)views
{
    if (_views != views) {
        _views = views;
        [self registerCells];
        [self setMinimumSpacing];
        [self reloadData];
    }
}

- (void) setShadowRadius:(CGFloat)shadowRadius
{
    if (_shadowRadius != shadowRadius) {
        _shadowRadius = shadowRadius;
        self.layer.mask = shadowRadius? self.shadowLayer : nil;
    }
}

- (CAGradientLayer *) shadowLayer
{
    if (!_shadowLayer) {
        
        UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout*)self.collectionViewLayout;
        UIColor *opaque = [UIColor clearColor];
        UIColor *transparent = [UIColor blackColor];
        
        _shadowLayer = [CAGradientLayer layer];
        _shadowLayer.frame = self.bounds;
        _shadowLayer.colors = @[(id)opaque.CGColor, (id)transparent.CGColor, (id)transparent.CGColor, (id)opaque.CGColor];
        _shadowLayer.anchorPoint = CGPointZero;
        
        CGFloat totalDistance;
        switch (layout.scrollDirection) {
                
            case UICollectionViewScrollDirectionHorizontal:
                totalDistance = self.bounds.size.width;
                _shadowLayer.startPoint = CGPointMake(0.0f, 0.5f);
                _shadowLayer.endPoint = CGPointMake(1.0f, 0.5f);
                break;
                
            case UICollectionViewScrollDirectionVertical:
                totalDistance = self.bounds.size.height;
                _shadowLayer.startPoint = CGPointMake(0.5f, 0.0f);
                _shadowLayer.endPoint = CGPointMake(0.5f, 1.0f);
                break;
        }
        
        CGFloat location1 = self.shadowRadius / totalDistance;
        CGFloat location2 = 1.0f - location1;
        _shadowLayer.locations = @[@0.0, @(location1), @(location2), @1.0];
    }
    return _shadowLayer;
}

- (void) registerCells
{
    for (NSUInteger i = 0; i < self.views.count; i++) {
        [self registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:PMReuseIdentifierForViewIndex(i)];
    }
}

- (void) setMinimumSpacing
{
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.collectionViewLayout;
    
    CGFloat contentWidth = 0.0f;
    CGFloat contentHeight = 0.0f;
    
    for (UIView *view in self.views) {
        contentWidth += view.frame.size.width;
        contentHeight += view.frame.size.height;
    }
    
    self.viewsSize = CGSizeMake(contentWidth, contentHeight);
    
    NSUInteger spaces = self.views.count - 1;
    CGFloat minimumInteritemSpacing = ceilf((self.bounds.size.width - contentWidth) / spaces + 1.0f);
    CGFloat minimumLineSpacing = ceilf((self.bounds.size.height - contentHeight) / spaces + 1.0f);
    
    if (minimumInteritemSpacing - layout.minimumInteritemSpacing > 0.0f) {
        layout.minimumInteritemSpacing = minimumInteritemSpacing;
    }
    
    if (minimumLineSpacing - layout.minimumLineSpacing > 0.0f) {
        layout.minimumLineSpacing = minimumLineSpacing;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self recenterIfNecessary];
}

- (void) recenterIfNecessary
{
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.collectionViewLayout;
    CGPoint currentOffset = self.contentOffset;
    
    switch (layout.scrollDirection) {
            
        case UICollectionViewScrollDirectionHorizontal: {

            CGFloat contentCenteredX = (self.contentSize.width - self.bounds.size.width) / 2.0f;
            CGFloat deltaFromCenter = currentOffset.x - contentCenteredX;
            CGFloat singleContentWidth = self.viewsSize.width + layout.minimumInteritemSpacing * self.views.count;
            
            if (fabsf(deltaFromCenter) >= singleContentWidth ) {
                
                CGFloat correction = (deltaFromCenter > 0)? deltaFromCenter - singleContentWidth : deltaFromCenter + singleContentWidth;
                
                currentOffset.x = contentCenteredX + correction;
            }
            break;
        }
        case UICollectionViewScrollDirectionVertical: {
            
            CGFloat contentCenteredY = (self.contentSize.height - self.bounds.size.height) / 2.0f;
            CGFloat deltaFromCenter = currentOffset.y - contentCenteredY;
            CGFloat singleContentHeight = self.viewsSize.height + layout.minimumLineSpacing * self.views.count;
            
            if (fabsf(deltaFromCenter) >= singleContentHeight) {
                
                CGFloat correction = (deltaFromCenter > 0)? deltaFromCenter - singleContentHeight : deltaFromCenter + singleContentHeight;
                
                currentOffset.y = contentCenteredY + correction;
            }
            break;
        }
    }
    
    self.contentOffset = currentOffset;
}


- (NSUInteger) viewIndexForIndexPath:(NSIndexPath *)indexPath
{
    return indexPath.item % self.views.count;
}

#pragma mark - UICollectionViewDatasource Methods


- (NSInteger) collectionView: (UICollectionView *) collectionView
      numberOfItemsInSection: (NSInteger) section
{
    return self.views.count * ContentMultiplier;
}

- (UICollectionViewCell *) collectionView:(UICollectionView *) collectionView
                   cellForItemAtIndexPath: (NSIndexPath *) indexPath
{
    NSUInteger viewIndex = [self viewIndexForIndexPath:indexPath];
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:PMReuseIdentifierForViewIndex(viewIndex)
                                                                           forIndexPath:indexPath];
    if (!cell.contentView.subviews.count) {
        
        UIView *view = self.views[viewIndex];
        [cell.contentView addSubview:view];
        
        UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.collectionViewLayout;
        PMDirection direction = layout.scrollDirection == UICollectionViewScrollDirectionHorizontal? PMDirectionVertical : PMDirectionHorizontal;
        [view centerInRect:cell.contentView.bounds forDirection:direction];
    }

    return cell;
}


#pragma mark - UICollectionViewDelegateFlowLayout Methods

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewFlowLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UIView *view = self.views[[self viewIndexForIndexPath:indexPath]];
    
    switch (collectionViewLayout.scrollDirection) {
        case UICollectionViewScrollDirectionHorizontal: return CGSizeMake(view.frame.size.width, self.bounds.size.height);
        case UICollectionViewScrollDirectionVertical: return CGSizeMake(self.bounds.size.width, view.frame.size.height);
    }
    
    if ([self.secondaryDelegate respondsToSelector:@selector(collectionView:layout:sizeForItemAtIndexPath:)]) {
        [self.secondaryDelegate collectionView:collectionView layout:collectionViewLayout sizeForItemAtIndexPath:indexPath];
    }
}

#pragma mark - UIScrollViewDelegate Methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (self.shadowRadius) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        self.shadowLayer.position = scrollView.contentOffset;
        [CATransaction commit];
    }
    
    if ([self.secondaryDelegate respondsToSelector:@selector(scrollViewDidScroll:)]) {
        [self.secondaryDelegate scrollViewDidScroll:scrollView];
    }
}

@end
