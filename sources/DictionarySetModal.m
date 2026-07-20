//	DictionarySetModal.m
//	kotonoko
//
//	Copyright 2001 - 2014 Atsushi Tagami. All rights reserved.
//

#import "PreferenceModal.h"
#import "DictionaryManager.h"
#import "DictionaryListItem.h"
#import "DictionarySetModal.h"

static void* kSelectionBindingIdentifier = (void*) @"ebookSet";
static void* kDictionariesBindingIdentifier = (void*) @"dictionaries";


@implementation DictionarySetModal

//-- init
// 初期化
-(id) init
{
	self = [super init];
	return self;
}


//-- dealloc
// 後片付け
-(void) dealloc
{
	[_dictionarySetController removeObserver:self forKeyPath:@"selection"];
	[[DictionaryManager sharedDictionaryManager] removeObserver:self forKeyPath:@"dictionaries"];
}


//-- finalize
// 後片付け


//-- awakeFromNib
// 
-(void) awakeFromNib
{
	[self initialize];
}


//-- initize
//
-(void) initialize
{
	if(_dictionarySetController){
		[_dictionarySetController addObserver:self
								   forKeyPath:@"selection"
									  options:0
									  context:kSelectionBindingIdentifier];
	}
	[[DictionaryManager sharedDictionaryManager] addObserver:self
												  forKeyPath:@"dictionaries"
													 options:0
													 context:kDictionariesBindingIdentifier];
	[self setSelectedDictionarySet];
	[self updateDictionaries];
	
}


#pragma mark Dictionary

@synthesize selectedDictionary = _selectedDictionary;

//-- hasDictionary
//
-(BOOL) hasDictionary:(NSString*) identifier
{
    if (!_selectedDictionary || !identifier) return NO;
	id array = [_selectedDictionary valueForKey:kEBookSetList];
	if(!array || ![array isKindOfClass:[NSArray class]]){ return NO; };
	return [array containsObject:identifier];
}


//-- addDictionary
//
-(void) addDictionary:(NSString*) identifier
{
    if (!_selectedDictionary || !identifier) return;
    if (![_selectedDictionary isKindOfClass:[NSDictionary class]]) return;
	[_selectedDictionary willChangeValueForKey:kEBookSetList];
	id existing = [_selectedDictionary valueForKey:kEBookSetList];
	NSMutableArray* array = nil;
	if (existing && [existing isKindOfClass:[NSArray class]]) {
		array = [existing mutableCopy];
	} else {
		array = [NSMutableArray array];
	}
	if (![array containsObject:identifier]) {
		[array addObject:identifier];
	}
	[_selectedDictionary setValue:array forKey:kEBookSetList];
	[_selectedDictionary didChangeValueForKey:kEBookSetList];
    [[PreferenceModal sharedPreference] savePreferencesToDefaults];
}



//-- removeDictionary
//
-(void) removeDictionary:(NSString*) identifier
{
    if (!_selectedDictionary || !identifier) return;
    if (![_selectedDictionary isKindOfClass:[NSDictionary class]]) return;
	[_selectedDictionary willChangeValueForKey:kEBookSetList];
	id existing = [_selectedDictionary valueForKey:kEBookSetList];
	if (existing && [existing isKindOfClass:[NSArray class]]) {
		NSMutableArray* array = [existing mutableCopy];
		[array removeObject:identifier];
		[_selectedDictionary setValue:array forKey:kEBookSetList];
	}
	[_selectedDictionary didChangeValueForKey:kEBookSetList];
    [[PreferenceModal sharedPreference] savePreferencesToDefaults];
}


#pragma mark Observer
//-- observeValueForKeyPath:ofObject:change:context:
//
- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
						change:(NSDictionary *)change
					   context:(void *)context
{	
	if (context == kSelectionBindingIdentifier) {
		[self setSelectedDictionarySet];
	}else if(context == kDictionariesBindingIdentifier){
		[self updateDictionaries];
	}else{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}


//-- setSelectedDictionarySet
// 選択されている辞書セットを設定する
-(void) setSelectedDictionarySet
{
	[self willChangeValueForKey:@"selectedDictionary"];
	_selectedDictionary = [[_dictionarySetController selectedObjects] lastObject];
	if(!_selectedDictionary || ![_selectedDictionary isKindOfClass:[NSDictionary class]] || [_selectedDictionary valueForKey:@"title"] == NSNoSelectionMarker){
		_selectedDictionary = nil;
	}
	[self didChangeValueForKey:@"selectedDictionary"];
	_dictionarySet = [[DictionaryManager sharedDictionaryManager] valueForKey:@"dictionaries"];
	[_tableView reloadData];
}


//-- updateDictionaries
// 辞書一覧の更新
-(void) updateDictionaries
{
	_dictionarySet = [[DictionaryManager sharedDictionaryManager] valueForKey:@"dictionaries"];
	[_tableView reloadData];
}


#pragma mark protocol:NSTableDataSource

//-- numberOfRowsInTableView
// 辞書の数を返す
-(NSInteger) numberOfRowsInTableView : (NSTableView*) aTableView
{
    return [_dictionarySet count];
}


//-- tableView:objectValueForTableColumn:row
// オブジェクトを返す
-(id)				tableView : (NSTableView*) aTableView
    objectValueForTableColumn : (NSTableColumn*) aTableColumn
						  row : (NSInteger) rowIndex
{
	static NSNumber *yes, *no;
	if(!yes){
		yes = [[NSNumber alloc] initWithBool:YES];
		no = [[NSNumber alloc] initWithBool:NO];
	}
	
	if(rowIndex >= 0 && rowIndex < [_dictionarySet count]){
		NSString* identifier = [aTableColumn identifier];
		id dict = [_dictionarySet objectAtIndex:rowIndex];
		if([identifier isEqualToString:@"title"]) {
			NSString* title = nil;
			if ([dict isKindOfClass:[DictionaryListItem class]]) {
				title = [(DictionaryListItem*)dict tagName];
			}
			if (!title || [title length] == 0) {
				title = [dict valueForKey:@"title"];
			}
			if (!title || [title length] == 0) {
				title = [dict valueForKey:@"id"];
			}
			return title ? title : @"";
		}else if([identifier isEqualToString:@"selected"]) {
			NSString* dictId = [dict valueForKey:@"id"];
			return (dictId && [self hasDictionary:dictId]) ? yes : no;
		}	
	}
	return @"";
}


//-- tableView:setObjectValue:forTableColumn:row
// データの変更
- (void) tableView : (NSTableView*)	aTableView
	setObjectValue : (id) anObject
	forTableColumn : (NSTableColumn *)	aTableColumn
			   row : (NSInteger) rowIndex
{
	id identifier = [aTableColumn identifier];
    
	if([identifier isEqualToString:@"selected"] && rowIndex >= 0 && rowIndex < [_dictionarySet count]) {
		NSString* dictId = [[_dictionarySet objectAtIndex:rowIndex] valueForKey:@"id"];
		if (dictId) {
			if([anObject boolValue] == YES){
				[self addDictionary:dictId];
			}else{
				[self removeDictionary:dictId];
			}
		}
    }
}


//-- tableView:willDisplayCell:forTableColumn:row
// table viewが選択された時の処理
-(void) tableView : (NSTableView*) tableView
  willDisplayCell : (id) cell 
   forTableColumn : (NSTableColumn *) tableColumn
			  row : (NSInteger) rowIndex
{
	[cell setEnabled:(_selectedDictionary != NULL)]; 
}


@end
