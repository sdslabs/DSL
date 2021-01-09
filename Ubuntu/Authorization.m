//
//  Authorization.m
//  Ubuntu
//
//  Created by Kanav Gupta on 09/01/21.
//

#import <Foundation/Foundation.h>

int auth (NSString *command, NSMutableArray *args) {
    @autoreleasepool {
        // Create authorization reference
        AuthorizationRef authorizationRef;
        OSStatus status;
        unsigned long numArgs = [args count];
        
        status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorizationRef);
        
        // Run the tool using the authorization reference
        char *argList[numArgs+1];
        for (int i = 0; i < numArgs; ++i) {
            argList[i] = [(NSString *) args[i] UTF8String];
        }
        argList[numArgs] = NULL;
        FILE *pipe = NULL;

        status = AuthorizationExecuteWithPrivileges(authorizationRef, (char *)[command UTF8String], kAuthorizationFlagDefaults, argList, &pipe);

        // Print to standard output
        char readBuffer[128];
        if (status == errAuthorizationSuccess) {
            for (;;) {
                ssize_t bytesRead = read(fileno(pipe), readBuffer, sizeof(readBuffer));
                if (bytesRead < 1) break;
                write(fileno(stdout), readBuffer, bytesRead);
            }
        } else {
            NSLog(@"Authorization Result Code: %d", status);
        }
    }
    return 0;
}
