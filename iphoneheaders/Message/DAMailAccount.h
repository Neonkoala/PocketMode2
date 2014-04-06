/**
 * This header is generated by class-dump-z 0.2-1.
 * class-dump-z is Copyright (C) 2009 by KennyTM~, licensed under GPLv3.
 *
 * Source: /System/Library/PrivateFrameworks/Message.framework/Message
 */

#import "MailAccount.h"

@class NSString, NSArray, NSObject, DAAccount, NSSet, NSCountedSet, DAMailbox, NSMutableDictionary;
@protocol ASAccountActorMessages;

@interface DAMailAccount : MailAccount {
	NSObject<ASAccountActorMessages>* _accountConduit;
	DAAccount* _daAccount;
	NSString* _cachedAccountID;
	NSString* _cachedDisplayName;
	NSString* _cachedEmailAddress;
	NSArray* _cachedEmailAddresses;
	BOOL _cachedCalendarEnabled;
	NSString* _cachedInboxFolderID;
	NSString* _cachedSentMessagesFolderID;
	NSString* _cachedTrashFolderID;
	DAMailbox* _temporaryInbox;
	BOOL _startListeningOnHierarchyChange;
	BOOL _loadedInitialMailboxList;
	BOOL _receivedInitialMailboxUpdate;
	BOOL _doneInitialInboxCheck;
	BOOL _observingPushedFoldersPrefsChanged;
	int _supportsServerSearch;
	unsigned _daysToSync;
	NSMutableDictionary* _requestQueuesByFolderID;
	NSSet* _watchedFolderIds;
	NSCountedSet* _userFocusMailboxIds;
}
+(id)folderIDForRelativePath:(id)relativePath accountID:(id*)anId;
+(id)accountDirectoryPrefix;
// inherited: +(id)displayedAccountTypeString;
// inherited: +(id)displayedShortAccountTypeString;
+(NSString*)_URLScheme;	// as
+(void)removeStaleExchangeDBRows;
+(void)_removeStaleExchangeDirectories:(id)directories;
+(id)accountIDForDirectoryName:(id)directoryName isAccountDirectory:(BOOL*)directory;
// inherited: +(id)basicAccountProperties;
// inherited: +(id)supportedDataclasses;
-(id)initWithDAAccount:(id)daaccount;
-(void)foldersContentsChanged:(id)changed;
// inherited: -(id)displayName;
// inherited: -(id)username;
// inherited: -(id)hostname;
// inherited: -(id)deliveryAccount;
// inherited: -(id)uniqueId;
// inherited: -(id)allMailboxUids;
// inherited: -(void)resetSpecialMailboxes;
// inherited: -(int)emptyFrequencyForMailboxType:(int)mailboxType;
-(BOOL)isRunningInPreferences;
-(id)accountConduit;
-(void)_loadChildren:(id)children forID:(id)anId intoBox:(id)box replacingInbox:(id)inbox withID:(id)anId5;
-(void)accountHierarchyChanged:(id)changed;
-(void)pushedFoldersPrefsChanged:(id)changed;
-(BOOL)finishedInitialMailboxListLoad;
// inherited: -(void)fetchMailboxList;
-(BOOL)_canReceiveNewMailNotifications;
// inherited: -(Class)storeClass;
-(id)_copyMailboxWithParent:(id)parent name:(id)name attributes:(unsigned)attributes permanentTag:(id)tag dictionary:(id)dictionary;
-(id)_copyMailboxUidWithParent:(id)parent name:(id)name attributes:(unsigned)attributes existingMailboxUid:(id)uid permanentTag:(id)tag dictionary:(id)dictionary;
-(id)_createMailboxWithParent:(id)parent name:(id)name attributes:(unsigned)attributes dictionary:(id)dictionary;
// inherited: -(BOOL)shouldAppearInMailSettings;
-(id)_URLScheme;
// inherited: -(id)mailboxPathExtension;
-(void)setDAAccount:(id)account;
-(id)syncAnchorForMailbox:(id)mailbox;
// inherited: -(BOOL)supportsRemoteAppend;
-(id)_infoForMatchingURL:(id)matchingURL;
-(id)mailboxForFolderID:(id)folderID;
// inherited: -(id)mailboxUidForInfo:(id)info;
-(void)addRequest:(id)request mailbox:(id)mailbox consumer:(id)consumer;
-(void)addRequests:(id)requests mailbox:(id)mailbox consumers:(id)consumers;
-(BOOL)moveMessages:(id)messages fromMailbox:(id)mailbox toMailbox:(id)mailbox3 markAsRead:(BOOL)read unsuccessfulOnes:(id)ones;
-(id)_specialMailboxUidWithType:(int)type create:(BOOL)create;
// inherited: -(id)primaryMailboxUid;
// inherited: -(id)accountPropertyForKey:(id)key;
// inherited: -(void)invalidate;
// inherited: -(void)dealloc;
// inherited: -(BOOL)reconstituteOrphanedMeetingInMessage:(id)message;
// inherited: -(BOOL)isEnabledForMeetings;
-(id)_inboxFolderID;
// inherited: -(void)startListeningForNotifications;
// inherited: -(void)stopListeningForNotifications;
// inherited: -(BOOL)canFetchMessagesByNumericRange;
-(id)syncAnchorForFolderID:(id)folderID mailbox:(id*)mailbox;
-(void)setSyncAnchor:(id)anchor forFolderID:(id)folderID mailbox:(id*)mailbox;
-(void)resetFolderID:(id)anId;
-(void)performSearchQuery:(id)query consumer:(id)consumer;
-(void)cancelSearchQuery:(id)query;
// inherited: -(BOOL)shouldDisplayHostnameInErrorMessages;
-(BOOL)shouldRestoreMessagesAfterFailedDelete;
-(BOOL)supportsServerSearch;
-(unsigned)daysToSync;
// inherited: -(void)addUserFocusMailbox:(id)mailbox;
// inherited: -(void)removeUserFocusMailbox:(id)mailbox;
@end

