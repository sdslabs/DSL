//
//  Authorization.m
//  Ubuntu
//
//  Created by Kanav Gupta on 09/01/21.
//

#import <Foundation/Foundation.h>
#include <sys/stat.h>

int auth (NSString *command, NSMutableArray *args, NSPipe *outputBuf) {
    @autoreleasepool {
        // Create authorization reference
        AuthorizationRef authorizationRef;
        OSStatus status;
        unsigned long numArgs = [args count];
        NSFileHandle *writer = [outputBuf fileHandleForWriting];
        
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
                [writer writeData: [NSData dataWithBytes:(const void *) readBuffer length: bytesRead]];
            }
        } else {
            NSLog(@"Authorization Result Code: %d", status);
        }
    }
    return 0;
}

int setuid_file (NSString *binaryPath) {
    @autoreleasepool {
        char* binary = (char *)[binaryPath UTF8String];
        struct stat info;
        stat(binary, &info);
        if (info.st_uid == 0 && info.st_mode & 1<<11)
        {
            return 0;
        }
        
        // Create authorization reference
        AuthorizationRef authorizationRef;
        OSStatus status;
        char readBuffer[128];

        status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorizationRef);
        
        // Run the tool using the authorization reference
        char *argListChown[] = { "root", binary, NULL };
        FILE *pipe = NULL;

        status = AuthorizationExecuteWithPrivileges(authorizationRef, "/usr/sbin/chown", kAuthorizationFlagDefaults, argListChown, &pipe);

        // Print to standard output
        if (status == errAuthorizationSuccess) {
            printf("success\n");
            for (;;) {
                ssize_t bytesRead = read(fileno(pipe), readBuffer, sizeof(readBuffer));
                if (bytesRead < 1) break;
                write(fileno(stdout), readBuffer, bytesRead);
            }
        } else {
            NSLog(@"Authorization Result Code: %d", status);
            return -1;
        }
        
        char *argListChmod[] = { "u+s", binary, NULL };
        status = AuthorizationExecuteWithPrivileges(authorizationRef, "/bin/chmod", kAuthorizationFlagDefaults, argListChmod, &pipe);
        if (status == errAuthorizationSuccess) {
            for (;;) {
                ssize_t bytesRead = read(fileno(pipe), readBuffer, sizeof(readBuffer));
                if (bytesRead < 1) break;
                write(fileno(stdout), readBuffer, bytesRead);
            }
        } else {
            NSLog(@"Authorization Result Code: %d", status);
            return -1;
        }
    }
    return 0;
}

