//
//  PhotoCellNode.m
//  Sample
//
//  Created by Hannah Troisi on 2/17/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
//  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "PhotoCellNode.h"
#import "Utilities.h"
#import "AsyncDisplayKit.h"
#import "ASDisplayNode+Beta.h"
#import "CommentsNode.h"
#import "PINImageView+PINRemoteImage.h"
#import "PINButton+PINRemoteImage.h"

#define DEBUG_PHOTOCELL_LAYOUT  0

#define HEADER_HEIGHT           50
#define USER_IMAGE_HEIGHT       30
#define HORIZONTAL_BUFFER       12
#define VERTICAL_BUFFER         5
#define FONT_SIZE               14

@interface PhotoCellNode () <ASVideoNodeDelegate>

@end

@implementation PhotoCellNode
{
  PhotoModel          *_photoModel;
  CommentsNode        *_photoCommentsView;
  ASNetworkImageNode  *_userAvatarImageView;
  ASNetworkImageNode  *_photoImageView;
  ASVideoNode         *_videoView;
  ASImageNode         *_iconImageView;

  ASTextNode          *_userNameLabel;
  ASTextNode          *_photoLocationLabel;
  ASTextNode          *_photoTimeIntervalSincePostLabel;
  ASTextNode          *_photoLikesLabel;
  ASTextNode          *_photoDescriptionLabel;
}

#pragma mark - Lifecycle

- (instancetype)initWithPhotoObject:(PhotoModel *)photo;
{
  self = [super init];
  
  if (self) {
    
    _photoModel              = photo;
    
    _iconImageView       = [[ASImageNode alloc] init];
    _iconImageView.image = [UIImage imageNamed:@"insta_icon"];

    _userAvatarImageView     = [[ASNetworkImageNode alloc] init];
    _userAvatarImageView.URL = photo.ownerUserProfile.userPicURL;   // FIXME: make round
    
    // FIXME: autocomplete for this line seems broken
    [_userAvatarImageView setImageModificationBlock:^UIImage *(UIImage *image) {
      CGSize profileImageSize = CGSizeMake(USER_IMAGE_HEIGHT, USER_IMAGE_HEIGHT);
      return [image makeCircularImageWithSize:profileImageSize];
    }];

    BOOL video = NO;
    if (video) {
      _videoView = [[ASVideoNode alloc] init];
      _videoView.delegate = self;
      _videoView.asset = [AVAsset assetWithURL:[NSURL URLWithString:@"https://files.parsetfss.com/8a8a3b0c-619e-4e4d-b1d5-1b5ba9bf2b42/tfss-753fe655-86bb-46da-89b7-aa59c60e49c0-niccage.mp4"]];
      _videoView.gravity = AVLayerVideoGravityResizeAspectFill;
      _videoView.backgroundColor = [UIColor clearColor];
      _videoView.shouldAutorepeat = YES;
      _videoView.shouldAutoplay = YES;
      _videoView.muted = YES;
    } else {
      _photoImageView          = [[ASNetworkImageNode alloc] init];
      _photoImageView.URL      = photo.URL;
      _photoImageView.layerBacked = YES;
    }
    
    _userNameLabel                  = [[ASTextNode alloc] init];
    _userNameLabel.attributedText   = [photo.ownerUserProfile usernameAttributedStringWithFont:[UIFont systemFontOfSize:FONT_SIZE weight:UIFontWeightMedium]];  
    
    _photoLocationLabel      = [[ASTextNode alloc] init];
    _photoLocationLabel.maximumNumberOfLines = 1;
    [photo.location reverseGeocodedLocationWithCompletionBlock:^(LocationModel *locationModel) {
      
      // check and make sure this is still relevant for this cell (and not an old cell)
      // make sure to use _photoModel instance variable as photo may change when cell is reused,
      // where as local variable will never change
      if (locationModel == _photoModel.location) {
        _photoLocationLabel.attributedText = [photo locationAttributedStringWithFontSize:FONT_SIZE];
        [self setNeedsLayout];
      }
    }];
    
    _photoTimeIntervalSincePostLabel = [self createLayerBackedTextNodeWithString:[photo uploadDateAttributedStringWithFontSize:FONT_SIZE]];
    _photoLikesLabel                 = [self createLayerBackedTextNodeWithString:[photo likesAttributedStringWithFontSize:FONT_SIZE]];
    _photoDescriptionLabel           = [self createLayerBackedTextNodeWithString:[photo descriptionAttributedStringWithFontSize:FONT_SIZE]];
    _photoDescriptionLabel.maximumNumberOfLines = 3;
    
    _photoCommentsView = [[CommentsNode alloc] init];
    // For now disable shouldRasterizeDescendants as it will throw an assertion: 'Node should always be marked invisible before deallocating. ...'
    //_photoCommentsView.shouldRasterizeDescendants = YES;
    
    // instead of adding everything addSubnode:
    self.automaticallyManagesSubnodes = YES;
    
#if DEBUG_PHOTOCELL_LAYOUT
    _userAvatarImageView.backgroundColor              = [UIColor greenColor];
    _userNameLabel.backgroundColor                    = [UIColor greenColor];
    _photoLocationLabel.backgroundColor               = [UIColor greenColor];
    _photoTimeIntervalSincePostLabel.backgroundColor  = [UIColor greenColor];
    _photoCommentsView.backgroundColor                = [UIColor greenColor];
    _photoDescriptionLabel.backgroundColor            = [UIColor greenColor];
    _photoLikesLabel.backgroundColor                  = [UIColor greenColor];
#endif
  }
  
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASNetworkImageNode *contentNode = _videoView != nil ? _videoView : _photoImageView;

  return
   // Main stack
   [ASStackLayoutSpec
    stackLayoutSpecWithDirection:ASStackLayoutDirectionVertical
    spacing:0
    justifyContent:ASStackLayoutJustifyContentStart
    alignItems:ASStackLayoutAlignItemsStretch
    children:@[

      // Header stack with inset
      [ASInsetLayoutSpec
       insetLayoutSpecWithInsets:UIEdgeInsetsMake(0, HORIZONTAL_BUFFER, 0, HORIZONTAL_BUFFER)
       child:
         // Header stack
         [ASStackLayoutSpec
          stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal
          spacing:0.0
          justifyContent:ASStackLayoutJustifyContentStart
          alignItems:ASStackLayoutAlignItemsCenter
          children:@[
            // Avatar image with inset
            [ASInsetLayoutSpec
             insetLayoutSpecWithInsets:UIEdgeInsetsMake(HORIZONTAL_BUFFER, 0, HORIZONTAL_BUFFER, HORIZONTAL_BUFFER)
             child:
               [_userAvatarImageView styledWithBlock:^(ASLayoutElementStyle *style) {
                 style.preferredSize = CGSizeMake(USER_IMAGE_HEIGHT, USER_IMAGE_HEIGHT);
               }]
            ],
            // User and photo location stack
            [[ASStackLayoutSpec
             stackLayoutSpecWithDirection:ASStackLayoutDirectionVertical
             spacing:0.0
             justifyContent:ASStackLayoutJustifyContentStart
             alignItems:ASStackLayoutAlignItemsStretch
             children:_photoLocationLabel.attributedText ? @[
               [_userNameLabel styledWithBlock:^(ASLayoutElementStyle *style) {
                 style.flexShrink = 1.0;
               }],
               [_photoLocationLabel styledWithBlock:^(ASLayoutElementStyle *style) {
                 style.flexShrink = 1.0;
               }]
             ] :
             @[
               [_userNameLabel styledWithBlock:^(ASLayoutElementStyle *style) {
                 style.flexShrink = 1.0;
               }]
             ]]
            styledWithBlock:^(ASLayoutElementStyle *style) {
              style.flexShrink = 1.0;
            }],
            // Spacer between user / photo location and insta icon inverval
            [[ASLayoutSpec new] styledWithBlock:^(ASLayoutElementStyle *style) {
              style.flexGrow = 1.0;
            }],
            // Insta icon interval node
            [_iconImageView styledWithBlock:^(ASLayoutElementStyle *style) {
              // to remove double spaces around spacer
              style.spacingBefore = HORIZONTAL_BUFFER;
            }]
          ]]
        ],
      
      [ASInsetLayoutSpec
       insetLayoutSpecWithInsets:UIEdgeInsetsMake(0, HORIZONTAL_BUFFER, 0, HORIZONTAL_BUFFER)
       child:
       // Center photo with ratio
        [ASRatioLayoutSpec
          ratioLayoutSpecWithRatio:1.0
          child:contentNode]
      ],
      
      // Footer stack with inset
      [ASInsetLayoutSpec
       insetLayoutSpecWithInsets:UIEdgeInsetsMake(VERTICAL_BUFFER, HORIZONTAL_BUFFER, VERTICAL_BUFFER, HORIZONTAL_BUFFER)
       child:
         [ASStackLayoutSpec
          stackLayoutSpecWithDirection:ASStackLayoutDirectionVertical
          spacing:VERTICAL_BUFFER
          justifyContent:ASStackLayoutJustifyContentStart
          alignItems:ASStackLayoutAlignItemsStretch
          children:@[
            [ASStackLayoutSpec
             stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal
             spacing:0.0
             justifyContent:ASStackLayoutJustifyContentStart
             alignItems:ASStackLayoutAlignItemsCenter
             children:@[
                        _photoLikesLabel,
                        // Spacer between likes and photo time inverval
                        [[ASLayoutSpec new] styledWithBlock:^(ASLayoutElementStyle *style) {
                            style.flexGrow = 1.0;
                        }],
                        [_photoTimeIntervalSincePostLabel styledWithBlock:^(ASLayoutElementStyle *style) {
                        // to remove double spaces around spacer
                            style.spacingBefore = HORIZONTAL_BUFFER;
                        }]
                      ]],
            _photoDescriptionLabel,
            _photoCommentsView
          ]]
       ]
    ]];
}

#pragma mark - Instance Methods

- (void)didEnterPreloadState
{
  [super didEnterPreloadState];
  
  [_photoModel.commentFeed refreshFeedWithCompletionBlock:^(NSArray *newComments) {
    [self loadCommentsForPhoto:_photoModel];
  }];
}

#pragma mark - Helper Methods

- (ASTextNode *)createLayerBackedTextNodeWithString:(NSAttributedString *)attributedString
{
  ASTextNode *textNode      = [[ASTextNode alloc] init];
  textNode.layerBacked      = YES;
  textNode.attributedText = attributedString;
  return textNode;
}

- (void)loadCommentsForPhoto:(PhotoModel *)photo
{
  if (photo.commentFeed.numberOfItemsInFeed > 0) {
    [_photoCommentsView updateWithCommentFeedModel:photo.commentFeed];
    
    [self setNeedsLayout];
  }
}

#pragma mark - Actions

- (void)didTapVideoNode:(ASVideoNode *)videoNode
{
//  if (videoNode == self.guitarVideoNode) {
//    if (videoNode.playerState == ASVideoNodePlayerStatePlaying) {
//      [videoNode pause];
//    } else if(videoNode.playerState == ASVideoNodePlayerStateLoading) {
//      [videoNode pause];
//    } else {
//      [videoNode play];
//    }
//    return;
//  }

  if (videoNode.player.muted == YES) {
    videoNode.player.muted = NO;
  } else {
    videoNode.player.muted = YES;
  }
}

#pragma mark - ASVideoNodeDelegate

- (void)videoNode:(ASVideoNode *)videoNode willChangePlayerState:(ASVideoNodePlayerState)state toState:(ASVideoNodePlayerState)toState
{
  if (toState == ASVideoNodePlayerStatePlaying) {
    NSLog(@"guitarVideoNode is playing");
  } else if (toState == ASVideoNodePlayerStateFinished) {
    NSLog(@"guitarVideoNode finished");
  } else if (toState == ASVideoNodePlayerStateLoading) {
    NSLog(@"guitarVideoNode is buffering");
  }
}

- (void)videoNode:(ASVideoNode *)videoNode didPlayToTimeInterval:(NSTimeInterval)timeInterval
{
  NSLog(@"guitarVideoNode playback time is: %f",timeInterval);
}


@end
