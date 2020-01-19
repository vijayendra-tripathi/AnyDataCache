//
//  DataCache.swift
//  RealmTest
//
//  Created by Vijayendra Tripathi on 15/01/20.
//  Copyright © 2020 Vijayendra Tripathi. All rights reserved.
//

/*
 References:
 https://www.maxmin.io/2017/02/26/Creating-Multiple-Realms-in-Swift/
 https://stackoverflow.com/questions/35525921/checking-when-a-date-has-passed-swift
 https://realm.io/blog/realm-objc-swift-2-6/#compact-on-launch
 https://github.com/realm/realm-cocoa/issues/4766
 */

import Foundation
import RealmSwift

class DataCache {
    
    private var storageLimitInBytes: Int = 5 * 1024 * 1024 // 5 MB default limit
    private let cacheFileName = "DataCache.realm"
    // create a searial queue to perform background operations.
    private let realmQueue = DispatchQueue(label: "com.datacache.serial")
    private var taskCount = 0 // task counts of serial queue
    
    /* A Singleton shared instance to access CachedData */
    public static var sharedInstance: DataCache = {
        let instance = DataCache()
        instance.deleteExpiredItems() // Some cleanup in background.
        NotificationCenter.default.addObserver(instance, selector:#selector(instance.calendarDayDidChange(_:)), name:NSNotification.Name.NSCalendarDayChanged, object:nil)
        return instance
    }()
    
    // Notification received on day change
    @objc private func calendarDayDidChange(_ notification : NSNotification) {
        print("Calendar date changed ...")
        deleteExpiredItems()
    }
    
    private func connectRealm() -> Realm? {
        let documentDirectory = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let url = documentDirectory.appendingPathComponent(cacheFileName)
        var config = Realm.Configuration()
        config.fileURL = url
        config.shouldCompactOnLaunch = { totalBytes, usedBytes in
            let desiredFileSize = 40 * 1024 * 1024 // 40 MB
            return (totalBytes > desiredFileSize) && ((Double(usedBytes) / Double(totalBytes)) < 0.5)
        }
//        print("Realm URL: \(url)")
        let realm = try! Realm(configuration: config)
        return realm
    }
    
    
    /*
     We always do this operation in background everytime day changes. We do this
     in background as it might take some time to find all expired items and so we
     should not block main thread.
    */
    public func deleteExpiredItems() {
        realmQueue.async {
            autoreleasepool {
                print("Deleting expired items ...")
                guard let realm = self.connectRealm() else {
                    print("Sorry, could not connect to realm file.")
                    return
                }
                
                let today = Date()
                let items = realm.objects(AnyData.self).filter("autoDelete == true AND expiryTime < %@", today)
                try! realm.write {
                    if items.count > 0 {
                        realm.delete(items)
                    }
                }
                
                // Invalidate realm
                realm.invalidate()
            }
        }
    }
    
    public func deleteItem(dataKey: String, onCompletion: @escaping () -> Void) {
        realmQueue.async {
            autoreleasepool {
                print("Deleting specified items ...")
                guard let realm = self.connectRealm() else {
                    print("Sorry, could not connect to realm file.")
                    return
                }
            
                let items = realm.objects(AnyData.self).filter("dataKey == %@", dataKey)
                try! realm.write {
                    if items.count > 0 {
                        realm.delete(items)
                        DispatchQueue.main.async {
                            onCompletion()
                        }
                    }
                }
                
                // Invalidate realm
                realm.invalidate()
            }
        }
    }
    
    // Limit in MegaBytes
    public func setStorageLimitInMB(limitMB: Int) {
        if limitMB > 0 {
            storageLimitInBytes = limitMB * 1024 * 1024 // Convert from MB to Bytes
        }
        else {
            print("Zero limit is not accepted. Default limit will be used.")
        }
    }
    
    /*
     We use background operation here because single item's data can be very big
     (hundreds of MB, who knows) and might take time to read it. We should not
     block main thread for that time. We return data on main thread using
     specified closure.
    */
    public func getData(dataKey: String, onFetch: @escaping (AnyData?) -> Void) {
        realmQueue.async {
            autoreleasepool {
                guard let realm = self.connectRealm() else {
                    return
                }
                
                let cachedData = realm.object(ofType: (AnyData.self), forPrimaryKey: dataKey)
                if let anyData = cachedData?.getStatelessCopy() {
                    DispatchQueue.main.async {
                        onFetch(anyData)
                    }
                }
                else {
                    DispatchQueue.main.async {
                        onFetch(nil)
                    }
                }
                
                // Invalidate realm
                realm.invalidate()
            }
        }
    }
    
    /*
     Again, we do this operation on a background thread as writing single data might
     take some time if it is in hundred's of MBs. We also need to do a cleanup
     if total data size (of auto delete objects) exceeds 'storeageLimitInMB'. This
     computation is also expensive and so we do all these in background serial queue.
     */
    public func addData(dataKey: String, data: Data, expiryTime: Date? = nil, autoDelete: Bool = true) {
        self.taskCount += 1
        realmQueue.async {
            autoreleasepool {
                guard let realm = self.connectRealm() else {
                    return
                }
                
                let cachedData = AnyData()
                cachedData.dataKey = dataKey
                cachedData.data = data
                cachedData.autoDelete = autoDelete
                cachedData.updateTime = Date()
                cachedData.expiryTime = expiryTime
                cachedData.dataSize = data.count
                try! realm.write {
                    realm.create(AnyData.self, value: cachedData, update: .all)
                }
                
                self.taskCount -= 1
                // Since this is a serial queue we do cleanup after last task is completed.
                if self.taskCount == 0 {
                    // Now check if data is exceeding storage limit allowed
                    let collectionResult = realm.objects(AnyData.self).filter("autoDelete == true").sorted(byKeyPath: "updateTime")
                    while collectionResult.sum(ofProperty: "dataSize") as Int > self.storageLimitInBytes {

                        // If exceeding then delete oldest object
                        if let oldestObject = collectionResult.first {
                            try! realm.write {
                                //print("Deleting object: \(oldestObject.dataKey)")
                                realm.delete(oldestObject)
                            }
                        }
                        else {
                            break
                        }
                    }
                    print("All tasks completed.")
                }
                
                // Invalidate realm
                realm.invalidate()
                
//                print("Pending task count: \(self.taskCount)")
            }
        }
    }
    
    
    // Removed day change notification
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
}
