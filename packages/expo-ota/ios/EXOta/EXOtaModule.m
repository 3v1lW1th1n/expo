// Copyright 2018-present 650 Industries. All rights reserved.

#import <EXOta/EXOtaModule.h>
#import <EXOta/EXKeyValueStorage.h>
#import <EXOta/EXOtaPersistance.h>
#import "EXOtaPersistanceFactory.h"
#import <EXOtaUpdater.h>
#import <EXExpoUpdatesConfig.h>

@interface EXOtaModule ()

@property (nonatomic, weak) UMModuleRegistry *moduleRegistry;

@end

@implementation EXOtaModule {
    EXOtaUpdater *updater;
    EXOtaPersistance *persistance;
}

UM_EXPORT_MODULE(ExpoOta);

- (id)init
{
    return [self configure:nil];
}

- (id)initWithId:(NSString *)appId
{
    return [self configure:appId];
}

- (id)configure:(NSString* _Nullable)appId
{
    persistance = [[EXOtaPersistanceFactory sharedFactory] persistanceForId:appId];
    updater = [[EXOtaUpdater alloc] initWithConfig:persistance.config withPersistance:persistance withId:persistance.appId];
    return self;
}

- (void)setModuleRegistry:(UMModuleRegistry *)moduleRegistry
{
    _moduleRegistry = moduleRegistry;
}

UM_EXPORT_METHOD_AS(checkForUpdateAsync,
                    checkForUpdateAsync:(UMPromiseResolveBlock)resolve
                    reject:(UMPromiseRejectBlock)reject)
{
    [updater downloadManifest:^(NSDictionary * _Nonnull manifest) {
        if([self isManifestNewer:manifest])
        {
            resolve(manifest);
        } else
        {
            resolve(@NO);
        }
    } error:^(NSError * _Nonnull error) {
        reject(@"ERR_EXPO_OTA", @"Could not download manifest", error);
    }];
}

- (BOOL) isManifestNewer:(NSDictionary * _Nonnull)manifest
{
    return [persistance.config.manifestComparator shouldDownloadBundle:[persistance readNewestManifest] forNew:manifest];
}

UM_EXPORT_METHOD_AS(fetchUpdatesAsync,
                    fetchUpdatesAsync:(UMPromiseResolveBlock)resolve
                    reject:(UMPromiseRejectBlock)reject)
{
    [updater checkAndDownloadUpdate:^(NSDictionary * _Nonnull manifest, NSString * _Nonnull filePath) {
        [self->updater saveDownloadedManifest:manifest andBundlePath:filePath];
        resolve(@{
            @"bundle": filePath
        });
    } updateUnavailable:^{
        resolve(nil);
    }   error:^(NSError * _Nonnull error) {
        reject(@"ERR_EXPO_OTA", @"Could not download update", error);
    }];
}

UM_EXPORT_METHOD_AS(clearUpdateCacheAsync,
                    clearUpdateCacheAsync:(UMPromiseResolveBlock)resolve
                    reject:(UMPromiseRejectBlock)reject)
{
    [updater cleanUnusedFiles];
    resolve(@YES);
}

UM_EXPORT_METHOD_AS(reload,
                    reload:(UMPromiseResolveBlock)resolve
                    reject:(UMPromiseRejectBlock)reject)
{
    [updater scheduleForExchangeAtNextBoot];
    resolve(@YES);
}

UM_EXPORT_METHOD_AS(reloadFromCache,
                    reloadFromCache:(UMPromiseResolveBlock)resolve
                    reject:(UMPromiseRejectBlock)reject)
{
    [self reload:resolve reject:reject];
}

@end
