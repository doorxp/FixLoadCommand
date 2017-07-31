//
//  main.m
//  mh
//
//  Created by doorxp on 2017/7/31.
//  Copyright © 2017年 doorxp. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <mach-o/loader.h>

@interface NSFileHandle(getcmd)
- (BOOL)getCmd:(void *)cmd length:(NSUInteger)length;
@end

@implementation NSFileHandle(getcmd)
- (BOOL)getCmd:(void *)cmd length:(NSUInteger)length {
    NSData *data = [self readDataOfLength:length];
    if (data != nil && data.length == length && !!cmd) {
        [data getBytes:cmd length:length];
        return true;
    }

    return false;
}
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...


        for (int i=0; i<argc; i++) {
            NSLog(@"%d:%s",i, argv[i]);
        }

        if (argc != 2) {
            return 0;
        }

        NSString *path = @(argv[1]);
        if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:nil]) {
            NSLog(@"%@ 不存在", path);
        }

        NSFileHandle *file = [NSFileHandle fileHandleForUpdatingAtPath:path];

        struct mach_header_64 header;
        [file seekToFileOffset:0];
        [file getCmd:&header length:sizeof(header)];

        if (header.magic == MH_MAGIC_64) {
            NSLog(@"MH_MAGIC_64");
        }
        else if (header.magic == MH_MAGIC_64) {
            NSLog(@"MH_MAGIC_64");
        }

        typedef struct __MHSECT  {
            int64_t offset;
            struct section_64 sects;
        }MHSECT;

        typedef struct __SC64 {
            NSUInteger offset;
            struct segment_command_64 cmd;
            MHSECT *startSects;
        }SC64;

        SC64 *scs = malloc(sizeof(SC64) * header.ncmds);

        for (int i = 0; i<header.ncmds; i++) {
           struct segment_command_64 *sc = &scs[i].cmd;
            bzero(sc, sizeof(*sc));
            scs[i].startSects = NULL;
            scs[i].offset = 0;

            scs[i].offset = [file offsetInFile];
            [file getCmd:sc length:sizeof(*sc)];

            if (sc->cmd != LC_SEGMENT_64) {
                continue;
            }

            scs[i].startSects = malloc(sizeof(MHSECT)*sc->nsects);
            for (int j =0; j<sc->nsects; j++) {
                struct section_64 *sect = &(scs->startSects[j].sects);
                bzero(sect, sizeof(*sect));
                scs->startSects[j].offset = [file offsetInFile];
                [file getCmd:sect length:sizeof(*sect)];
            }
        }

        for (int i = 0; i<header.ncmds; i++) {
            struct segment_command_64 *sc = &scs[i].cmd;

            if (sc->cmd != LC_SEGMENT_64) {
                continue;
            }

            for (int j =0; j<sc->nsects; j++) {
                struct section_64 *sect = &(scs->startSects[j].sects);

                uint64_t fileoff = sect->addr - sc->vmaddr + sc->fileoff;

                sect->offset = (uint32_t)(fileoff);

                if (j<sc->nsects-1) {
                    struct section_64 *nextSect = &(scs->startSects[j+1].sects);
                    sect->size = nextSect->addr-sect->addr;
                }
                else {
                    sect->size = scs[i+1].cmd.vmaddr - sect->addr;
                }
            }
        }

        for (int i = 0; i<header.ncmds; i++) {
            struct segment_command_64 *sc = &scs[i].cmd;

            if (sc->cmd != LC_SEGMENT_64) {
                continue;
            }

            for (int j =0; j<sc->nsects; j++) {
                struct section_64 *sect = &(scs->startSects[j].sects);
                uint64 offset = scs->startSects[j].offset;
                [file seekToFileOffset:offset];
                NSData *data = [NSData dataWithBytes:sect length:sizeof(*sect)];
                [file writeData:data];
            }
        }

        for (int i = 0; i<header.ncmds; i++) {
            struct segment_command_64 *sc = &scs[i].cmd;

            if (sc->cmd != LC_SEGMENT_64) {
                continue;
            }

            for (int j =0; j<sc->nsects; j++) {
                if((&scs[i])->startSects)free((&scs[i])->startSects);
                (&scs[i])->startSects = NULL;
            }
        }

        if(scs)free(scs);
        scs = NULL;

        [file synchronizeFile];
        [file closeFile];

        NSLog(@"Hello, World!");
    }
    return 0;
}
