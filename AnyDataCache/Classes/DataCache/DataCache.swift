//
//    CachedData.swift
//    AnyDataCache
//
//    Copyright (c) 2020 Vijayendra Tripathi

//    Permission is hereby granted, free of charge, to any person obtaining a copy
//    of this software and associated documentation files (the "Software"), to deal
//    in the Software without restriction, including without limitation the rights
//    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//    copies of the Software, and to permit persons to whom the Software is
//    furnished to do so, subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//    SOFTWARE.
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

public class DataCache {
    
    private var storageLimitInBytes: Int = 5 * 1024 * 1024 // 5 MB default limit
    private let cacheFileName = "DataCache.realm"
    /*
     Create a searial queue to perform background operations. You can also use a
     concurrent queue but that may increase realm database file substentially. It
     also reduces compacting opportunities if realm file is accessed by a background
     thread.
     */
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
//        print("Calendar date changed ...")
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
//                print("Deleting expired items ...")
                guard let realm = self.connectRealm() else {
                    print("Sorry, could not connect to realm file.")
                    return
                }
                
                let today = Date()
                let items = realm.objects(AnyData.self).filter("autoDelete == true AND expiryTime < %@", today)
                
                do {
                    try realm.write {
                        if items.count > 0 {
                            realm.delete(items)
                        }
                    }
                }
                catch {
                    // You might want to log this.
                    print("Can't delete expired item.")
                }
                
                // Invalidate realm
                realm.invalidate()
            }
        }
    }
    
    public func deleteItem(dataKey: String, onCompletion: @escaping (Bool) -> Void) {
        realmQueue.async {
            autoreleasepool {
//                print("Deleting specified items ...")
                guard let realm = self.connectRealm() else {
                    print("Sorry, could not connect to realm file.")
                    DispatchQueue.main.async {
                        onCompletion(false)
                    }
                    return
                }
            
                let items = realm.objects(AnyData.self).filter("dataKey == %@", dataKey)
                do {
                    try realm.write {
                        if items.count > 0 {
                            realm.delete(items)
                            DispatchQueue.main.async {
                                onCompletion(true)
                            }
                        }
                    }
                }
                catch {
                    print("Deletion failed for key: \(dataKey)")
                    DispatchQueue.main.async {
                        onCompletion(false)
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
                    DispatchQueue.main.async {
                        onFetch(nil)
                    }
                    return
                }
                
                let cachedData = realm.object(ofType: (AnyData.self), forPrimaryKey: dataKey)
                let anyData = cachedData?.getStatelessCopy()
                DispatchQueue.main.async {
                    onFetch(anyData)
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
    public func addData(dataKey: String, data: Data, expiryTime: Date? = nil, autoDelete: Bool = true, onAdd: @escaping (Bool) -> Void) {
        self.taskCount += 1
        realmQueue.async {
            autoreleasepool {
                guard let realm = self.connectRealm() else {
                    DispatchQueue.main.async {
                        onAdd(false)
                    }
                    return
                }
                
                let cachedData = AnyData()
                cachedData.dataKey = dataKey
                cachedData.data = data
                cachedData.autoDelete = autoDelete
                cachedData.updateTime = Date()
                cachedData.expiryTime = expiryTime
                cachedData.dataSize = data.count
                do {
                    try realm.write {
                        realm.create(AnyData.self, value: cachedData, update: .all)
                    }
                }
                catch {
                    DispatchQueue.main.async {
                        onAdd(false)
                    }
                    return
                }
                
                self.taskCount -= 1
                // Since this is a serial queue we do cleanup after last task is completed.
                if self.taskCount == 0 {
                    // Now check if data is exceeding storage limit allowed
                    let collectionResult = realm.objects(AnyData.self).filter("autoDelete == true").sorted(byKeyPath: "updateTime")
                    while collectionResult.sum(ofProperty: "dataSize") as Int > self.storageLimitInBytes {

                        // If exceeding then delete oldest object
                        if let oldestObject = collectionResult.first {
                            do {
                                try realm.write {
                                    //print("Deleting object: \(oldestObject.dataKey)")
                                    realm.delete(oldestObject)
                                }
                            }
                            catch {
                                print("Failed to delte old item with key: \(oldestObject.dataKey)")
                            }
                        }
                        else {
                            break
                        }
                    }
//                    print("All tasks completed.")
                }
                
                DispatchQueue.main.async {
                    onAdd(true)
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

