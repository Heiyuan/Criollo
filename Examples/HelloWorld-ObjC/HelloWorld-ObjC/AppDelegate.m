//
//  AppDelegate.m
//  HelloWorld-ObjC
//
//  Created by Cătălin Stan on 11/19/15.
//  Copyright © 2015 Catalin Stan. All rights reserved.
//

#import "AppDelegate.h"
#import "utils.h"

#define PortNumber          10781
#define LogConnections          1
#define LogRequests             1

@interface AppDelegate () <CRServerDelegate>

@property (nonatomic, strong) CRHTTPServer *server;
@property (nonatomic, strong) NSURL *baseURL;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

    // Create the server and add some handlers to do some work
    self.server = [[CRHTTPServer alloc] initWithDelegate:self];

    // Prints a simple hello world as text/plain
    CRRouteHandlerBlock helloBlock = ^(CRRequest *request, CRResponse *response, void (^completionHandler)(void) ) {
        [response setValue:@"text/plain" forHTTPHeaderField:@"Content-type"];
        [response sendString:@"Hello World"];
        completionHandler();
    };
    [self.server addHandlerBlock:helloBlock forPath:@"/"];

    // Prints a hello world JSON object as application/json
    CRRouteHandlerBlock jsonHelloBlock = ^(CRRequest *request, CRResponse *response, void (^completionHandler)(void) ) {

        NSError *jsonError;
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:@{@"status": @YES, @"message": @"Hello World"} options:NSJSONWritingPrettyPrinted error:&jsonError];

        if ( jsonError != nil ) {
            [response setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-type"];
            [response sendData:jsonData];
        } else {
            [response setValue:@"text/plain; charset=utf-8" forHTTPHeaderField:@"Content-type"];
            [response sendString:jsonError.localizedDescription];
        }
        completionHandler();

    };
    [self.server addHandlerBlock:jsonHelloBlock forPath:@"/json"];

    // Prints some more info as text/html
    NSString *uname = systemInfo();
    CRRouteHandlerBlock statusBlock = ^(CRRequest *request, CRResponse *response, void (^completionHandler)(void) ) {

        NSDate *startTime = [NSDate date];

        NSMutableString *responseString = [NSMutableString string];

        // Bundle info
        NSBundle *bundle= [NSBundle mainBundle];
        [responseString appendFormat:@"<h1>%@</h1>", bundle.bundleIdentifier ];
        [responseString appendFormat:@"<h2>Version %@ build %@</h2>", [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"], [bundle objectForInfoDictionaryKey:@"CFBundleVersion"]];

        // Headers
        [responseString appendString:@"<h3>Request Headers:</h2><pre>"];
        [request.allHTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
            [responseString appendFormat:@"%@: %@\n", key, obj];
        }];
        [responseString appendString:@"</pre>"];

        // Request enviroment
        [responseString appendString:@"<h3>Request Enviroment:</h2><pre>"];
        [request.env enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
            [responseString appendFormat:@"%@: %@\n", key, obj];
        }];
        [responseString appendString:@"</pre>"];

        // Stack trace
        [responseString appendString:@"<h3>Stack Trace:</h2><pre>"];
        [[NSThread callStackSymbols] enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [responseString appendFormat:@"%@\n", obj];
        }];
        [responseString appendString:@"</pre>"];

        // System info
        [responseString appendString:@"<hr/>"];
        [responseString appendFormat:@"<small>%@</small><br/>", uname];
        [responseString appendFormat:@"<small>Task took: %.4fms</small>", [startTime timeIntervalSinceNow] * -1000];

        [response setValue:@"text/html; charset=utf-8" forHTTPHeaderField:@"Content-type"];
        [response setValue:@(responseString.length).stringValue forHTTPHeaderField:@"Content-Length"];
        [response sendString:responseString];

        completionHandler();

    };
    [self.server addHandlerBlock:statusBlock forPath:@"/status"];

    // Start listening
    NSError *serverError;
    if ( [self.server startListening:&serverError portNumber:PortNumber] ) {

        // Output some nice info to the console

        // Get server ip address
        NSString *address;
        BOOL result = getIPAddress(&address);
        if ( !result ) {
            address = @"127.0.0.1";
        }

        // Set the base url. This is only for logging
        self.baseURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:%d", address, PortNumber]];

        [CRApp logFormat:@"Started HTTP server at %@", self.baseURL.absoluteString];

        // Get the list of paths
        NSDictionary<NSString*, NSMutableArray<CRRoute*>*>* routes = [[self.server valueForKey:@"routes"] mutableCopy];
        NSMutableSet<NSURL*>* paths = [NSMutableSet set];
        [routes enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSMutableArray<CRRoute *> * _Nonnull obj, BOOL * _Nonnull stop) {
            NSString* path = [key substringFromIndex:[key rangeOfString:@"/"].location + 1];
            [paths addObject:[self.baseURL URLByAppendingPathComponent:path]];
        }];

        NSArray<NSURL*>* sortedPaths =[paths sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"absoluteString" ascending:YES]]];

        [CRApp logFormat:@"Available paths are:"];
        [sortedPaths enumerateObjectsUsingBlock:^(NSURL * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [CRApp logFormat:@" * %@", obj.absoluteString];
        }];
        
    } else {
        [CRApp logErrorFormat:@"Failed to start HTTP server. %@", serverError.localizedDescription];
        [CRApp terminate:nil];
    }

}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self.server stopListening];
}

#if LogConnections
- (void)server:(CRServer *)server didAcceptConnection:(CRConnection *)connection {
    [CRApp logFormat:@" * Accepted connection from %@:%d", connection.remoteAddress, connection.remotePort];
}

- (void)server:(CRServer *)server didCloseConnection:(CRConnection *)connection {
    [CRApp logFormat:@" * Disconnected %@:%d", connection.remoteAddress, connection.remotePort];
}
#endif

#if LogRequests
- (void)server:(CRServer *)server didFinishRequest:(CRRequest *)request {
    [CRApp logFormat:@" * %@ %@ - %lu - %@", request.response.connection.remoteAddress, request, request.response.statusCode, request.env[@"HTTP_USER_AGENT"]];
}
#endif


@end