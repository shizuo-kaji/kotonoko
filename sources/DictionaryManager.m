//	DictionaryManager.m
//	kotonoko
//
//	Copyright 2001 - 2014 Atsushi Tagami. All rights reserved.
//

#import "DictionaryListItem.h"
#import "DictionaryManager.h"
#import "PreferenceModal.h"
#import "PreferenceDefines.h"
#import "EBook.h"

#import "NetDictionary.h"


DictionaryManager* sSharedDictionaryManager = NULL;

@implementation DictionaryManager
@synthesize readableAll = _readableAll;


#pragma mark Shared Instance
//-- sharedDictionaryManager
// return shared preference 
+(DictionaryManager*) sharedDictionaryManager
{
	if(!sSharedDictionaryManager){
		sSharedDictionaryManager = [[DictionaryManager alloc] init];
	}
	return sSharedDictionaryManager;
}


#pragma mark Initializing
//-- init
// 初期化
- (id) init
{
	self = [super init];
    if(self){
        if(sSharedDictionaryManager){
            return sSharedDictionaryManager;
        }
        sSharedDictionaryManager = self;
	
        _root = [[NSMutableArray alloc] init];
        _dictionaries = [[NSMutableArray alloc] init];
	}
	return self;
}


//-- dealloc
// メモリの解放


//-- initialize
// 初期化
-(void) initialize
{
	[self createDictionaryArray];
	[self createNetDictionaryArray];
}


#pragma mark Dictionaries
//-- addDictionary
// 辞書を追加
-(void) addDictionary:(id <DictionaryProtocol>) item
{
    if (!item) return;
    if (![_dictionaries containsObject:item]) {
        NSIndexSet *indexset = [NSIndexSet indexSetWithIndex:[_dictionaries count]];
        [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexset forKey:@"dictionaries"];
        [_dictionaries addObject:item];
        [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexset forKey:@"dictionaries"];
        id obj = item;
        NSLog(@"[addDictionary] ADDED item id=%@, title=%@, path=%@. Total count=%lu", [obj valueForKey:@"id"], [obj valueForKey:@"title"], [obj valueForKey:@"path"], (unsigned long)[_dictionaries count]);
    } else {
        id obj = item;
        NSLog(@"[addDictionary] SKIPPED (already in _dictionaries) item id=%@", [obj valueForKey:@"id"]);
    }
}


//-- removeDictionary
// 辞書を削除
-(void) deleteDictionary:(id <DictionaryProtocol>) item
{
	NSUInteger index = [_dictionaries indexOfObject:item];
	if (index != NSNotFound) {
		NSIndexSet *indexset = [NSIndexSet indexSetWithIndex:index];
		[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexset forKey:@"dictionaries"];
		[_dictionaries removeObjectAtIndex:index];
		[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexset forKey:@"dictionaries"];	
	}
}


//-- deleteDictionary
// 辞書を削除
-(void) deleteDictionaryAtIndex:(NSIndexSet*) indices
{
	if(indices){
		[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indices forKey:@"dictionaries"];
		[_dictionaries removeObjectsAtIndexes:indices];
		[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indices forKey:@"dictionaries"];	
	}
}


//-- dictionaryForIdentity
// IDで辞書を返す
-(id <DictionaryProtocol>) dictionaryForIdentity:(NSString*) identity
{
	for(id item in _dictionaries){
		if([item respondsToSelector:@selector(valueForKey:)]){
			if([identity isEqualToString:[item valueForKey:@"id"]]){
				return item;
			}
		}
	}
	return nil;
}


//-- dictionaryForEBookNumber
// ebook numberから DictionaryListItemを返す
-(EBook*) ebookForEBookNumber:(NSUInteger) number
{
	for(id item in _dictionaries){
		EBook* eb = [item valueForKey:@"ebook"];
		if (eb && [eb respondsToSelector:@selector(ebookNumber)] && [eb ebookNumber] == number) {
			return eb;
		}
		if([item respondsToSelector:@selector(ebookNumber)]){
			if([item ebookNumber] == number){
				return [item valueForKey:@"ebook"];
			}
		}
	}
	return nil;
}



//-- uniqueDictionaryIdFromPath:directory:
// パスからユニークな辞書IDを生成する
-(NSString*) uniqueDictionaryIdFromPath:(NSString*) path
							  directory:(NSString*) directoryName
{
    if (!path) path = @"";
    if (!directoryName) directoryName = @"";
	NSString* fullpath = [path stringByAppendingPathComponent:directoryName];
	NSString* identifier = [PreferenceModal dictionaryIdForFullPath:fullpath];
	
	identifier = (identifier == nil) ? directoryName : identifier;
	
	int counter = 1;
	id item;
	while((item = [self dictionaryForIdentity:identifier]) != nil){
		if([fullpath isEqualToString:[item valueForKey:@"path"]]){
			return [item valueForKey:@"id"] ? [item valueForKey:@"id"] : identifier;
		}
		identifier = [NSString stringWithFormat:@"%@.%d", directoryName, counter++];
	}
	if(counter > 1){
		[PreferenceModal setDictionaryId:identifier forFullPath:fullpath];
	}
	return identifier;
}


#pragma mark Scan Dictionaries
//-- createDictionaryArray
// 辞書リスト用配列の生成
-(void) createDictionaryArray
{
	NSEnumerator* dictionaies = [[PreferenceModal prefForKey:kDirectoryPath] objectEnumerator];
	
	if(_progressTimer){
		[_progressTimer invalidate];
	}
    
    self.readableAll = YES;
	_progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.00
													  target:self
													selector:@selector(scanDictionary:)
													userInfo:dictionaies
													 repeats:NO];
}


//-- scanDictionary
// 辞書を読み込む
-(void) scanDictionary:(NSTimer*) timer
{
	id obj = [[timer userInfo] nextObject];
	if(obj){
        NSFileManager* fm = [NSFileManager defaultManager];
        if([fm fileExistsAtPath:obj] == YES && [fm isReadableFileAtPath:obj] == NO){
            if ([PreferenceModal securityBookmarkForPath:obj] == nil){
                self.readableAll = NO;
            }
        }
        [self appendDirectory:obj];
        _progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.00
														  target:self
														selector:@selector(scanDictionary:)
														userInfo:[timer userInfo]
														 repeats:NO];		
	}else{
		_progressTimer = nil;
        [[NSNotificationCenter defaultCenter]
			postNotificationName:kDidInitializeDictionaryManager object:self userInfo:
                [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:[self readableAll]] forKey:kAllDictionariesIsLoaded]];
	}
}


+(BOOL) isEPWINGDirectory:(NSString*)path
{
    if (!path || [path length] == 0) return NO;
    BOOL isDir = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] || !isDir) return NO;
    
    NSArray* contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
    for (NSString* file in contents) {
        NSString* lower = [file lowercaseString];
        if ([lower isEqualToString:@"catalog"] || [lower isEqualToString:@"catalogs"] ||
            [lower hasPrefix:@"catalog."] || [lower hasPrefix:@"catalogs."]) {
            return YES;
        }
    }
    return NO;
}


//-- appendDirectory
// 辞書パスの追加
-(void) appendDirectory:(NSString*) path
{
    if (!path || [path length] == 0) return;
    NSURL* bookmark = [PreferenceModal securityBookmarkForPath:path];
    
    if (bookmark) [bookmark startAccessingSecurityScopedResource];
	DictionaryListItem* item = [DictionaryListItem dictionaryListItemWithPath:path];
	[self expandDirectory:item recursion:YES bookmark:bookmark];
	if ([[item children] count] > 0 || [[item valueForKey:@"type"] isEqualToString:@"book"]) {
		NSIndexSet *indexset = [NSIndexSet indexSetWithIndex:[_root count]];
		[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexset forKey:@"root"];
		[_root addObject:item];
		[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexset forKey:@"root"];
	}
    if (bookmark) [bookmark stopAccessingSecurityScopedResource];
}



//-- expandDirectory
// 辞書を展開する
-(void) expandDirectory : (DictionaryListItem*) parent
			  recursion : (BOOL) recursion
               bookmark :(NSURL*) bookmark
{
	NSString* path = [parent valueForKey:@"path"];
	if (!path || [path length] == 0) return;
	
	if ([DictionaryManager isEPWINGDirectory:path]) {
		EBook* book = [[EBook alloc] init];
		if([book bind:path]){
			[parent setValue:@"book" forKey:@"type"];
			int booknum = [book subbookNum];
			int i;
			for(i=0; i<booknum; i++){
				if([book selectSubbook:i]){
					NSString* dictionaryId = [self uniqueDictionaryIdFromPath:path directory:[book directoryName]];
					if(dictionaryId){
						[book loadPrefFromFile:nil];
						[book setSecurityScopeBookmark:bookmark];
						EBDictionary* item = [EBDictionary dictionaryListItemWithEBook:book path:path identify:dictionaryId];
						[parent addChild:item];
						[self addDictionary:item];
						
						book = [[EBook alloc] init];
						[book bind:path];
					}
				}
			}
			return;
		}
	}
	
	if(recursion){
		[parent setValue:@"folder" forKey:@"type"];
        
        NSError* error = nil;
		NSArray* fileList = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:&error];
		for(int i=0; i<[fileList count]; i++){
			NSString* fileName = [fileList objectAtIndex:i];
			if ([fileName hasPrefix:@"."]) continue; // Skip hidden files (.DS_Store, .git, etc.)
			
			NSString* ext = [[fileName pathExtension] lowercaseString];
			if ([ext isEqualToString:@"app"] || [ext isEqualToString:@"framework"] || 
			    [ext isEqualToString:@"xcodeproj"] || [ext isEqualToString:@"photoslibrary"] ||
			    [ext isEqualToString:@"dmg"] || [ext isEqualToString:@"zip"] || [ext isEqualToString:@"tar"] ||
			    [ext isEqualToString:@"gz"] || [ext isEqualToString:@"pkg"] || [ext isEqualToString:@"iso"]) {
				continue;
			}
			
			NSString* new_path = [path stringByAppendingPathComponent:fileName];
			
			NSDictionary* attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:new_path error:nil];
			if ([[attrs fileType] isEqualToString:NSFileTypeSymbolicLink]) continue;
			
			BOOL isDirectory = NO;
			if([[NSFileManager defaultManager] fileExistsAtPath:new_path isDirectory:&isDirectory] && isDirectory){
				DictionaryListItem* item = [DictionaryListItem dictionaryListItemWithPath:new_path];
				[self expandDirectory:item recursion:YES bookmark:bookmark];
				if ([[item children] count] > 0 || [[item valueForKey:@"type"] isEqualToString:@"book"]) {
					[parent addChild:item];
				}
			}
		}
	}
}


//-- removeDirectory
// ディレクトリの消去 返り値は削除したディレクトリのindex
-(NSUInteger) removeDirectory:(DictionaryListItem*) item
{
	NSUInteger index = [_root indexOfObject:item];
	if(index == NSNotFound || index > [_root count]) return NSNotFound;
	
	[self removeDictionaryListItem:item];
	NSIndexSet* indices = [NSIndexSet indexSetWithIndex:index];
	[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indices forKey:@"root"];
	// 各ディレクトリの担当辞書の更新
 	[_root removeObjectAtIndex:index];
	[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indices forKey:@"root"];
	return index;
}


//-- removeDictionaryListItem
// directory itemの削除
-(void) removeDictionaryListItem:(DictionaryListItem*) item
{
	NSMutableIndexSet* indeces = [[NSMutableIndexSet alloc] init];
	
	if([item children]){
		NSEnumerator* e =[[item children] objectEnumerator];
		DictionaryListItem* it;
		while(it = [e nextObject]){
			[self removeDictionaryListItem:it];
		}
	}
	if([[item valueForKey:@"type"] isEqualToString:@"dictionary"]){
		NSUInteger index = [_dictionaries indexOfObject:item];
		if(index != NSNotFound){
			[indeces addIndex:index];
		}
	}
	if([indeces count] > 0){
		[self deleteDictionaryAtIndex:indeces];
	}
}


#pragma mark Net Dictionaries
//-- createNetDictionaryArray
// ネットワーク辞書の走査
-(void) createNetDictionaryArray
{
	NSArray* files = [[NSBundle mainBundle] pathsForResourcesOfType:@"plist" inDirectory:@"NetDict"];
	_netDictionaries = [[NSMutableArray alloc] initWithCapacity:[files count]];
	
	for(NSString* path in files){
		NSData *data = [NSData dataWithContentsOfFile:path];
		NetDictionary* dict = [NetDictionary netDictionaryWithData:data];
		if(dict){
			[_netDictionaries addObject:dict];
			NSString* directoryName = [[path lastPathComponent] stringByDeletingPathExtension];
			NSString* identify = [self uniqueDictionaryIdFromPath:@"" directory:directoryName];
			[dict setValue:identify forKey:@"id"];
			//[self addDictionary:dict];
		}
	}
}


@end
