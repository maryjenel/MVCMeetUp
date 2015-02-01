//
//  Event.m
//  MeetMeUp
//
//  Created by Dave Krawczyk on 9/8/14.
//  Copyright (c) 2014 Mobile Makers. All rights reserved.
//

#define kEventDataFileName @"eventsData"
#define kCommentsDataFileName @"commentsData"

#import "Event.h"

@implementation Event


- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    if (self) {
        
        self.name = dictionary[@"name"];
        self.eventID = dictionary[@"id"];
        self.RSVPCount = dictionary[@"yes_rsvp_count"];
        self.hostedBy = dictionary[@"group"][@"name"];
        self.eventDescription = dictionary[@"description"];
        self.address = dictionary[@"venue"][@"address"];
        self.eventURL = [NSURL URLWithString:dictionary[@"event_url"]];
        self.photoURL = [NSURL URLWithString:dictionary[@"photo_url"]];
    }
    return self;
}

-(void)setAttending:(BOOL)attending
{
    if (attending)
    {
    _attending = attending;
    int rsvpCount = [self.RSVPCount intValue]; //custom setter.. if you want to change a value.
    self.RSVPCount = [NSNumber numberWithInt:rsvpCount+1]; //_rsvpCount does not contain a value
    }
    else
    {
        _attending = attending;
        int rsvpCount = [self.RSVPCount intValue]; //custom setter.. if you want to change a value.
        self.RSVPCount = [NSNumber numberWithInt:rsvpCount-1];
    }

}

+ (NSArray *)eventsFromArray:(NSArray *)incomingArray
{
    NSMutableArray *newArray = [[NSMutableArray alloc] initWithCapacity:incomingArray.count];
    
    for (NSDictionary *d in incomingArray) {
        Event *e = [[Event alloc]initWithDictionary:d];
        [newArray addObject:e];
        
    }
    return newArray;
}

- (NSURL *)fileURLForEventDataWithEventID:(NSString *)eventID
{
    NSString *filename = [NSString stringWithFormat:@"%@_%@",kCommentsDataFileName,self.eventID];
    NSURL *url = [[NSBundle mainBundle] URLForResource:filename withExtension:@""];
    return url;
}

+ (NSURL *)fileURLForCommentsForKeyword:(NSString *)keyword
{
    NSURL *url = [[NSBundle mainBundle] URLForResource:[NSString stringWithFormat:@"%@_%@",kEventDataFileName,keyword] withExtension:@""];

    return url;
}

- (void)getCommentsWithBlock:(void (^)(NSArray *))commentBlock
{

    if ([[[NSProcessInfo processInfo] environment] objectForKey:@"XCInjectBundle"])
    {
        NSString *path = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"commentsData_%@", self.eventID] ofType:@""]; //the file is a document. use @"" find the path...
        NSData *data = [NSData dataWithContentsOfFile:path];
        NSArray *jsonArray = [[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil]objectForKey:@"results"];
        commentBlock([Comment objectsFromArray:jsonArray]);
    }
    else
    {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.meetup.com/2/event_comments?&sign=true&photo-host=public&event_id=%@&page=20&key=4b6a576833454113112e241936657e47",self.eventID]];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {

                               NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
                               
                               NSArray *jsonArray = [dict objectForKey:@"results"];

                               commentBlock([Comment objectsFromArray:jsonArray]);
                           }];
    }
    
}

- (void)retreiveImageWithComplete:(void (^)(NSData *data))complete
{
    if (self.photoURL)
    {
        NSURLRequest *imageReq = [NSURLRequest requestWithURL:self.photoURL];

        [NSURLConnection sendAsynchronousRequest:imageReq queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!connectionError)
                {
                    complete(data);
                }else
                {
                    complete(nil);
                }
            });
        }];
    }
    else
    {
        complete(nil);
    }
}

+ (void)performSearchWithKeyword:(NSString *)keyword andComplete:(void (^)(NSArray *))complete
{
    if ([[[NSProcessInfo processInfo] environment] objectForKey:@"XCInjectBundle"]) // returns whether or not if you are running unit tests versus running the app.
    {
        NSString *path = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"eventsData_%@", keyword] ofType:@""]; //the file is a document. use @"" find the path...
        NSData *data = [NSData dataWithContentsOfFile:path];
        NSArray *jsonArray = [[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil]objectForKey:@"results"]; //returns a dictionary results returns an array.. must go inside the dictionary and return the array
        complete([Event eventsFromArray:jsonArray]); //sending an array of events

    }
    else
    {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.meetup.com/2/open_events.json?zip=60604&text=%@&time=,1w&key=4b6a576833454113112e241936657e47",keyword]];

    NSURLRequest *request = [NSURLRequest requestWithURL:url];

    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {

                               NSArray *jsonArray = [[NSJSONSerialization JSONObjectWithData:data
                                                                                     options:NSJSONReadingAllowFragments
                                                                                       error:nil] objectForKey:@"results"];

                               complete([Event eventsFromArray:jsonArray]);
                           }];
    }

}

@end
