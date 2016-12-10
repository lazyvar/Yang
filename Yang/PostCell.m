//
//  PostCell.m
//  Yang
//
//  Created by Biggie Smallz on 1/11/16.
//  Copyright © 2016 Mack Hasz. All rights reserved.
//

#import "PostCell.h"

@implementation PostCell
@synthesize delegate;

- (void)awakeFromNib {
    [super awakeFromNib];
    [self setUp];
}

-(void) configureCell:(PostCell *) cell forObject:(PFObject *) object withDelegate:(id<PostCellDelegate, ProPicDelegate>) theDelegate {
    [self configureCell:cell forObject:object withIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] withDelegate:theDelegate];
}

-(void) configureCell:(PostCell *) cell forObject:(PFObject *) object withIndexPath:(NSIndexPath *) indexPath withDelegate:(id<PostCellDelegate, ProPicDelegate>) theDelegate {
    
    PFUser *theSender = [object objectForKey:kPostSenderKey];
    PFUser *theReceiver = [object objectForKey:kPostReceiverKey];
    
    int amt = [[object objectForKey:@"amt"] intValue];
    
    if (cell.sender != nil && cell.receiver != nil) {
        [cell.sender setTheUser:theSender];
        [cell.receiver setTheUser:theReceiver];

        NSString *givr_name = theSender[@"first"];
        NSString *takr_name = theReceiver[@"first"];
        
        cell.fromUserLbl.text = [[NSString alloc] initWithFormat:@"%@ → %d", givr_name, amt];
        cell.toUserLbl.text = [[NSString alloc] initWithFormat:@"%@", takr_name];
    }

    NSDate * date = object.createdAt;
    cell.dateLabel.text = [date.shortTimeAgoSinceNow lowercaseString];

    cell.words.text = [object objectForKey:@"text"];

    [cell setNeedsLayout];
    [cell layoutIfNeeded];
    
    if (object[@"photo"]) {
        cell.mediaPreview.hidden = NO;
        PFFile *photo = [object objectForKey:@"photo"];
        [cell.mediaPreview sd_setImageWithURL:[NSURL URLWithString:photo.url]];

    } else {
        cell.mediaPreview.hidden = NO;
        PFFile *thumbnail = [object objectForKey:@"thumbnail"];
        [cell.mediaPreview sd_setImageWithURL:[NSURL URLWithString:thumbnail.url]];
    }

    cell.sender.delegate = theDelegate;
    cell.receiver.delegate = theDelegate;
    
    [theSender fetchIfNeededInBackgroundWithBlock:^(PFObject * _Nullable object, NSError * _Nullable error) {
        [cell.sender setTheUser:theSender];
        [cell.sender setNeedsLayout];
    }];
    
    [theReceiver fetchIfNeededInBackgroundWithBlock:^(PFObject * _Nullable object, NSError * _Nullable error) {
        [cell.receiver setTheUser:theReceiver];
        [cell.receiver setNeedsLayout];
    }];
    
    cell.selectionStyle = UITableViewCellSelectionStyleGray;
    
    cell.delegate = theDelegate;
    cell.post = object;
    cell.tag = indexPath.row;

    cell.mediaPreview.layer.cornerRadius = 22.0f;
    cell.mediaPreview.contentMode = UIViewContentModeScaleAspectFill;
    [cell.mediaPreview.layer  setMasksToBounds:YES];
    
    NSDictionary *attributesForPost = [[YCash sharedCache] attributesForPost:object];
    
    if (attributesForPost) {
        [cell setUpvoteStatus:[[YCash sharedCache] currentUserGaveUpvoteForPost:object]];
        [cell.upvotes setText:[NSString stringWithFormat:@"+ %@", [[[YCash sharedCache] upvoteCountForPost:object] stringValue]]];
        //[cell.comment_btn setTitle:[self formatCommentsLabel:[[[YCash sharedCache] commentCountForPost:object] intValue]] forState:UIControlStateNormal];
        
        if (cell.upvotes.alpha < 1.0f /* || cell.comment_btn.alpha < 1.0f*/ ) {
            [UIView animateWithDuration:0.200f animations:^{
                cell.upvotes.alpha = 1.0f;
                //cell.comment_btn.alpha = 1.0f;
            }];
        }
    } else {
        cell.upvotes.alpha = 0.0f;
        //cell.comment_btn.alpha = 0.0f;
        
        @synchronized(theDelegate) {
            // check if we can update the cache
            NSNumber *outstandingSectionHeaderQueryStatus = [theDelegate.outstandingQueries objectForKey:@(indexPath.row)];
            if (!outstandingSectionHeaderQueryStatus) {
                PFQuery *query = [YUtil queryForActivitiesOnPost:object cachePolicy:kPFCachePolicyNetworkOnly];
                [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
                    @synchronized(theDelegate) {
                        [theDelegate.outstandingQueries removeObjectForKey:@(indexPath.row)];
                        
                        if (error) {
                            return;
                        }
                        
                        NSMutableArray *upvoters = [NSMutableArray array];
                        NSMutableArray *commenters = [NSMutableArray array];
                        
                        BOOL currentUserGaveUpvote = NO;
                        
                        for (PFObject *activity in objects) {
                            if ([[activity objectForKey:kActivityTypeKey] isEqualToString:kActivityTypeUpvote] && [activity objectForKey:kActivityFromUserKey]) {
                                [upvoters addObject:[activity objectForKey:kActivityFromUserKey]];
                            } /*else if ([[activity objectForKey:kActivityTypeKey] isEqualToString:kActivityTypeComment] && [activity objectForKey:kActivityFromUserKey]) {
                                [commenters addObject:[activity objectForKey:kActivityFromUserKey]];
                            }*/
                            
                            if ([[[activity objectForKey:kActivityFromUserKey] objectId] isEqualToString:[[PFUser currentUser] objectId]]) {
                                if ([[activity objectForKey:kActivityTypeKey] isEqualToString:kActivityTypeUpvote]) {
                                    currentUserGaveUpvote = YES;
                                }
                            }
                        }
                        
                        [[YCash sharedCache] setAttributesForPost:object upvoters:upvoters commenters:commenters upvotedByCurrentUser:currentUserGaveUpvote];
                        
                        if (cell.tag != indexPath.row) {
                            return;
                        }
                        
                        [cell setUpvoteStatus:[[YCash sharedCache] currentUserGaveUpvoteForPost:object]];
                        [cell.upvotes setText:[NSString stringWithFormat:@"+ %@", [[[YCash sharedCache] upvoteCountForPost:object] stringValue]]];
                        //[cell.comment_btn setTitle:[self formatCommentsLabel:[[[YCash sharedCache] commentCountForPost:object] intValue]] forState:UIControlStateNormal];
                        
                        if (cell.upvotes.alpha < 1.0f /* || cell.comment_btn.alpha < 1.0f */) {
                            [UIView animateWithDuration:0.200f animations:^{
                                cell.upvotes.alpha = 1.0f;
                                //cell.comment_btn.alpha = 1.0f;
                            }];
                        }
                    }
                }];
            }
        }
    }

}

//-(NSString *) formatCommentsLabel:(int) numComments {
//    if (numComments == 0) {
//        return @"NO COMMENTS";
//    } else if (numComments == 1) {
//        return @"1 COMMENT";
//    } else {
//        return [NSString stringWithFormat:@"%d COMMENTS", numComments];
//    }
//}


-(void) setUp {

    [_up_btn setBackgroundImage:[UIImage imageNamed:@"up-arrow-active"] forState:UIControlStateSelected];
    [_up_btn setBackgroundImage:[UIImage imageNamed:@"up-arrow"] forState:UIControlStateNormal];
    
    self.contentView.userInteractionEnabled = NO;
}

-(void) setPost:(PFObject *)aPost {
    _post = aPost;
    [_ghost_btn addTarget:self action:@selector(didTapUpvoteButton:) forControlEvents:UIControlEventTouchUpInside];
    //[_comment_btn addTarget:self action:@selector(didTapCommentButton:) forControlEvents:UIControlEventTouchUpInside];
}


- (void)setUpvoteStatus:(BOOL)upvote {
    [self.up_btn setSelected:upvote];
    if (upvote) {
        [self.upvotes setTextColor:[YUtil theColor]];
    } else {
        [self.upvotes setTextColor:[UIColor lightGrayColor]];
    }
}

-(void)didTapUpvoteButton:(UIButton *)button {
    if (delegate && [delegate respondsToSelector:@selector(didTapUpvoteButton:forPostCell:forPost:)]) {
        [delegate didTapUpvoteButton:button forPostCell:self forPost:_post];
    }
}

-(void) didTapCommentButton:(UIButton *)button {
    if (delegate && [delegate respondsToSelector:@selector(didTapCommentButton:forPostCell:forPost:)]) {
        [delegate didTapCommentButton:button forPostCell:self forPost:_post];
    }
}


@end
