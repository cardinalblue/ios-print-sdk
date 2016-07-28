//
//  Modified MIT License
//
//  Copyright (c) 2010-2016 Kite Tech Ltd. https://www.kite.ly
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The software MAY ONLY be used with the Kite Tech Ltd platform and MAY NOT be modified
//  to be used with any competitor platforms. This means the software MAY NOT be modified
//  to place orders with any competitors to Kite Tech Ltd, all orders MUST go through the
//  Kite Tech Ltd platform servers.
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//


#import "OLImagePickerPhotosPageViewController.h"
#import "UIImageView+FadeIn.h"
#import "OLRemoteImageView.h"
#import "OLUserSession.h"
#import "OLImagePickerPhotosPageViewController+Facebook.h"
#import "OLImagePickerPhotosPageViewController+Instagram.h"
#import "UIView+RoundRect.h"

@interface OLImagePickerPhotosPageViewController () <UICollectionViewDelegateFlowLayout, UICollectionViewDataSource, UICollectionViewDelegate>
@property (weak, nonatomic) IBOutlet UIImageView *albumLabelChevron;
@property (assign, nonatomic) CGSize rotationSize;
@property (strong, nonatomic) UIVisualEffectView *visualEffectView;
@property (weak, nonatomic) IBOutlet UIView *albumsContainerView;
@property (weak, nonatomic) IBOutlet UIView *albumsCollectionViewContainerView;
@property (assign, nonatomic) NSInteger showingCollectionIndex;

@end

NSInteger OLImagePickerMargin = 0;

@implementation OLImagePickerPhotosPageViewController

- (void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    
    if (self.albumsContainerView.transform.ty != 0){
        [self userDidTapOnAlbumLabel:nil];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.albumsCollectionView.dataSource = self;
    self.albumsCollectionView.delegate = self;
    
    self.albumsCollectionView.transform = CGAffineTransformMakeRotation(M_PI);
    
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    self.albumLabel.text = NSLocalizedString(@"All Photos", @"");
    self.albumLabelChevron.transform = CGAffineTransformMakeRotation(M_PI);
    
    UIVisualEffect *blurEffect;
    blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight];
    
    self.visualEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    UIView *view = self.visualEffectView;
    [self.albumLabelContainer insertSubview:view belowSubview:self.albumLabel];
    
    view.translatesAutoresizingMaskIntoConstraints = NO;
    NSDictionary *views = NSDictionaryOfVariableBindings(view);
    NSMutableArray *con = [[NSMutableArray alloc] init];
    
    NSArray *visuals = @[@"H:|-0-[view]-0-|",
                         @"V:|-0-[view]-0-|"];
    
    
    for (NSString *visual in visuals) {
        [con addObjectsFromArray: [NSLayoutConstraint constraintsWithVisualFormat:visual options:0 metrics:nil views:views]];
    }
    
    [view.superview addConstraints:con];
    
    [self.view bringSubviewToFront:self.albumsContainerView];
    
    if (self.provider.providerType == OLImagePickerProviderTypeFacebook && (self.provider.collections.count == 0 || self.provider.collections[self.showingCollectionIndex].count == 0)){
        [self loadFacebookAlbums];
    }
    else if (self.provider.providerType == OLImagePickerProviderTypeInstagram && (self.provider.collections.count == 0 || self.provider.collections[self.showingCollectionIndex].count == 0)){
        [self startImageLoading];
    }
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    self.rotationSize = size;
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinator> context){
        [self.collectionView reloadData];
        [self.collectionView.collectionViewLayout invalidateLayout];
    }completion:^(id<UIViewControllerTransitionCoordinator> context){
        
    }];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    if (collectionView.tag == 10){
        return [self.provider.collections.firstObject count];
    }
    else{
        return [self.provider.collections count];
    }
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    UICollectionViewCell *cell;
    if (collectionView.tag == 10){
        cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"photoCell" forIndexPath:indexPath];
        OLRemoteImageView *imageView = [cell viewWithTag:10];
        [self setAssetOfCollection:self.provider.collections[self.showingCollectionIndex] withIndex:indexPath.item toImageView:imageView forCollectionView:collectionView];
        
        UIImageView *checkmark = [cell viewWithTag:20];
        id asset = [self.provider.collections.firstObject objectAtIndex:indexPath.item];
        OLAsset *printPhoto;
        if ([asset isKindOfClass:[PHAsset class]]){
            printPhoto = [OLAsset assetWithPHAsset:asset];
        }
        else if ([asset isKindOfClass:[OLAsset class]]){
            printPhoto = asset;
        }
        
        if ([[OLUserSession currentSession].userSelectedPhotos containsObject:printPhoto]){
            checkmark.hidden = NO;
        }
        else{
            checkmark.hidden = YES;
        }
    }
    else{
        cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"albumCell" forIndexPath:indexPath];
        cell.contentView.transform = CGAffineTransformMakeRotation(M_PI);
        OLRemoteImageView *imageView = [cell viewWithTag:10];
        [self setAssetOfCollection:self.provider.collections[indexPath.item] withIndex:0 toImageView:imageView forCollectionView:collectionView];
        [imageView makeRoundRectWithRadius:4];
        imageView.clipsToBounds = YES;
        
        cell.clipsToBounds = NO;
        cell.layer.shadowColor = [[UIColor blackColor] CGColor];
        cell.layer.shadowOpacity = .4;
        cell.layer.shadowRadius = 5;
        
        UILabel *label = [[cell viewWithTag:20] viewWithTag:30];
        label.text = self.provider.collections[indexPath.item].name;
    }
    
    return cell;
}

- (void)setAssetOfCollection:(OLImagePickerProviderCollection *)collection withIndex:(NSInteger)index toImageView:(OLRemoteImageView *)imageView forCollectionView:(UICollectionView *)collectionView{
    id asset = [collection objectAtIndex:index];
    
    if ([asset isKindOfClass:[PHAsset class]]){
        PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
        options.synchronous = NO;
        options.networkAccessAllowed = YES;
        options.deliveryMode = PHImageRequestOptionsDeliveryModeOpportunistic;
        options.resizeMode = PHImageRequestOptionsResizeModeFast;
        
        //TODO progress
        
        CGSize cellSize = [self collectionView:collectionView layout:collectionView.collectionViewLayout sizeForItemAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0]];
        [imageView setAndFadeInImageWithPHAsset:asset size:CGSizeMake(cellSize.width * [OLUserSession currentSession].screenScale, cellSize.height * [OLUserSession currentSession].screenScale) options:options];
    }
    else if ([asset isKindOfClass:[OLAsset class]]){
        [imageView setAndFadeInImageWithOLAsset:asset size:imageView.frame.size applyEdits:NO placeholder:nil completionHandler:NULL];
    }
}

- (NSUInteger)numberOfCellsPerRow{
    CGSize size = self.rotationSize.width != 0 ? self.rotationSize : self.view.frame.size;
    if (self.quantityPerItem == 3){
        return 3;
    }
    
    if (self.traitCollection.horizontalSizeClass != UIUserInterfaceSizeClassCompact){
        if (size.height > size.width){
            return [self findFactorOf:self.quantityPerItem maximum:6 minimum:6];
        }
        else{
            return [self findFactorOf:self.quantityPerItem maximum:6 minimum:6];
        }
    }
    else{
        if (size.height > size.width){
            return [self findFactorOf:self.quantityPerItem maximum:3 minimum:3];
        }
        else{
            return [self findFactorOf:self.quantityPerItem maximum:6 minimum:6];
        }
    }
}

- (NSInteger) findFactorOf:(NSInteger)qty maximum:(NSInteger)max minimum:(NSInteger)min{
    if (qty == 1){
        return 3;
    }
    min = MAX(1, min);
    max = MAX(1, max);
    NSInteger factor = max;
    while (factor > min) {
        if (qty % factor == 0){
            return factor;
        }
        else{
            factor--;
        }
    }
    return min;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section{
    if (collectionView.tag == 10){
        return OLImagePickerMargin;
    }
    else{
        return 0;
    }
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section{
    if (collectionView.tag == 10){
        return OLImagePickerMargin;
    }
    else{
        return 0;
    }
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    CGSize size = self.view.bounds.size;
    
    if (self.rotationSize.width != 0){
        size = self.rotationSize;
    }
    
    if (collectionView.tag == 10){
        
        
        float numberOfCellsPerRow = [self numberOfCellsPerRow];
        CGFloat width = ceilf(size.width/numberOfCellsPerRow);
        CGFloat height = width;
        
        
        return CGSizeMake(width, height);
    }
    else{
        return CGSizeMake(size.width - 16, 225);
    }
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section{
    if (collectionView.tag == 10){
        CGSize size = self.rotationSize.width != 0 ? self.rotationSize : self.view.frame.size;
        
        CGSize cellSize = [self collectionView:collectionView layout:collectionView.collectionViewLayout sizeForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
        CGFloat diff = size.width - (cellSize.width * [self numberOfCellsPerRow]);
        return UIEdgeInsetsMake(0, diff/2.0, 0, diff/2.0);
    }
    else{
        return UIEdgeInsetsMake(10, 0, 0, 0);
    }
}



- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    if (collectionView.tag == 10){
        id asset = [self.provider.collections.firstObject objectAtIndex:indexPath.item];
        OLAsset *printPhoto;
        if ([asset isKindOfClass:[PHAsset class]]){
            printPhoto = [OLAsset assetWithPHAsset:asset];
        }
        else if ([asset isKindOfClass:[OLAsset class]]){
            printPhoto = asset;
        }
        if ([[OLUserSession currentSession].userSelectedPhotos containsObject:printPhoto]){
            [[OLUserSession currentSession].userSelectedPhotos removeObject:printPhoto];
            [[collectionView cellForItemAtIndexPath:indexPath] viewWithTag:20].hidden = YES;
        }
        else{
            [[OLUserSession currentSession].userSelectedPhotos addObject:printPhoto];
            [[collectionView cellForItemAtIndexPath:indexPath] viewWithTag:20].hidden = NO;
        }
        
        [self.imagePicker updateTitleBasedOnSelectedPhotoQuanitity];
    }
    else{
        self.showingCollectionIndex = indexPath.item;
        [self.collectionView reloadData];
        [self userDidTapOnAlbumLabel:nil];
        self.albumLabel.text = self.provider.collections[self.showingCollectionIndex].name;
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    //TODO: ignore albums collectionview scrolling
    
    if (self.provider.providerType == OLImagePickerProviderTypeInstagram){
        if (self.inProgressMediaRequest == nil && scrollView.contentOffset.y >= self.collectionView.contentSize.height - self.collectionView.frame.size.height) {
            // we've reached the bottom, lets load the next page of instagram images.
            [self loadNextInstagramPage];
        }
    }
    else if (self.provider.providerType == OLImagePickerProviderTypeFacebook){
        if (self.inProgressRequest == nil && scrollView.contentOffset.y >= self.collectionView.contentSize.height - self.collectionView.frame.size.height) {
            // we've reached the bottom, lets load the next page of facebook images.
            [self loadNextFacebookPage];
        }
    }
}

- (IBAction)userDidTapOnAlbumLabel:(UITapGestureRecognizer *)sender {
    BOOL isOpening = CGAffineTransformIsIdentity(self.albumsContainerView.transform);
    
    if (isOpening){
        self.nextButton.hidden = NO;
        self.imagePicker.nextButton.hidden = YES;
    }
    else{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.25 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            self.imagePicker.nextButton.hidden = NO;
            self.nextButton.hidden = YES;
        });
    }
    
    if (isOpening){
        [UIView animateWithDuration:0.1 animations:^{
            self.albumsCollectionViewContainerView.alpha = 1;
        }];
    }
    else{
        [UIView animateWithDuration:0.1 delay:0.1 options:0 animations:^{
            self.albumsCollectionViewContainerView.alpha = 0;
        } completion:NULL];
    }
    
    [UIView animateWithDuration:0.8 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0 options:0 animations:^{
        self.albumsContainerView.transform = isOpening ? CGAffineTransformMakeTranslation(0, self.view.frame.size.height - (self.albumsContainerView.frame.origin.y + self.albumsContainerView.frame.size.height)) : CGAffineTransformIdentity;
        
        self.albumLabelChevron.transform = isOpening ? CGAffineTransformIdentity : CGAffineTransformMakeRotation(M_PI);
    }completion:^(BOOL finished){}];
}

- (IBAction)userDidDragAlbumLabel:(UIPanGestureRecognizer *)sender {
    {
        static CGFloat originalY;
        
        if (sender.state == UIGestureRecognizerStateBegan){
            originalY = self.albumsContainerView.transform.ty;
        }
        else if (sender.state == UIGestureRecognizerStateChanged){
            CGFloat closedY = self.albumsContainerView.frame.origin.y - self.albumsContainerView.transform.ty;
            CGFloat openTY = (self.view.frame.size.height - (closedY + self.albumsContainerView.frame.size.height));
            CGPoint translate = [sender translationInView:sender.view.superview];
            self.albumsContainerView.transform = CGAffineTransformMakeTranslation(0, MAX(translate.y + originalY, 0));
            
            CGFloat percentComplete = MAX(self.albumsContainerView.transform.ty, 0) / (openTY);
            self.albumLabelChevron.transform = CGAffineTransformMakeRotation(M_PI * (1- MIN(percentComplete, 1)));
            
            self.nextButton.hidden = percentComplete <= 0.5;
            self.imagePicker.nextButton.hidden = percentComplete > 0.5;
            
            self.albumsCollectionViewContainerView.alpha = MIN(percentComplete * 10, 1);
            
        }
        else if (sender.state == UIGestureRecognizerStateEnded ||
                 sender.state == UIGestureRecognizerStateFailed ||
                 sender.state == UIGestureRecognizerStateCancelled){
            CGFloat closedY = self.albumsContainerView.frame.origin.y - self.albumsContainerView.transform.ty;
            CGFloat openTY = (self.view.frame.size.height - (closedY + self.albumsContainerView.frame.size.height));
            
            BOOL opening = [sender velocityInView:sender.view].y > 0;
            
            CGFloat start = self.albumsContainerView.transform.ty;
            CGFloat ty = opening ? openTY : 0;
            
            CGFloat distance = ABS(start - ty);
            CGFloat total = openTY;
            CGFloat percentComplete = 1 - distance / total;
            
            CGFloat damping = ABS(0.6 + (0.6 * percentComplete)*(0.6 * percentComplete));
            CGFloat time = ABS(0.8 - (0.8 * percentComplete));
            
            if (opening){
                self.nextButton.hidden = NO;
                self.imagePicker.nextButton.hidden = YES;
                
                [UIView animateWithDuration:0.1 animations:^{
                    self.albumsCollectionViewContainerView.alpha = 1;
                }];
            }
            else{
                [UIView animateWithDuration:time/8.0 delay:0.1 options:0 animations:^{
                    self.albumsCollectionViewContainerView.alpha = 0;
                } completion:NULL];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.25 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    self.nextButton.hidden = YES;
                    self.imagePicker.nextButton.hidden = NO;
                });
            }
            
            
            [UIView animateWithDuration:time delay:0 usingSpringWithDamping:damping initialSpringVelocity:0 options:0 animations:^{
                self.albumsContainerView.transform = CGAffineTransformMakeTranslation(0, ty);
                self.albumLabelChevron.transform = opening ? CGAffineTransformIdentity : CGAffineTransformMakeRotation(M_PI);
            }completion:^(BOOL finished){}];
        }
    }
}


@end
