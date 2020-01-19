//
//  CachedData.swift
//  RealmTest
//
//  Created by Vijayendra Tripathi on 15/01/20.
//  Copyright © 2020 Vijayendra Tripathi. All rights reserved.
//

import Foundation
import RealmSwift

class AnyData: Object {
    
    @objc dynamic var dataKey: String = "" // Can be a URL, facebook id etc.
    @objc dynamic var data: Data? = nil // Any data, typically images, audio, video etc
    @objc dynamic var updateTime: Date? = nil // Time of creation or update
    @objc dynamic var autoDelete: Bool = true // No automatic deletion possible unless requested.
    @objc dynamic var expiryTime: Date? = nil // Automatically deleted after time expires.
    @objc dynamic var dataSize: Int = 0 // Data size in bytes.
    
    override static func primaryKey() -> String? {
        return "dataKey"
    }
    
    /*
     Since we do not keep the connection open after reading a data, we should return
     a stateless copy which don't require open connection. This has pros and cons -
     
     PROS -
     1. We can close connection after returning a stateless copy, thus giving Realm
     opportunity to do compacting (if needed) while opening subsequent connections. It
     is useful in our case as datacache is expected to write huge blobs into database
     and also perform cleanup of expired or old items. Even thouh we delete old data,
     Realm do not free disk space unless it gets compacting opportunity.
     2. Using stateless copies gives us option to do all reads on background thread and
     thus it frees main thread for UI operations. This is typically useful if we read
     huge blobs like HD image or video and we don't expect updates on them.
     
     CONS -
     1. Stateless copy approach creates data and returns it to main thread and then
     invalidates realm, thus any updates on such data may not be automatically
     available throught realm. As a workaround, we can monitor data update calls and
     take actions acordingly.
     
     */
    func getStatelessCopy() -> AnyData {
        let cachedData = AnyData()
        cachedData.dataKey = self.dataKey
        cachedData.data = self.data
        cachedData.updateTime = self.updateTime
        cachedData.updateTime = self.updateTime
        cachedData.autoDelete = self.autoDelete
        cachedData.expiryTime = self.expiryTime
        cachedData.dataSize = self.dataSize
        return cachedData
    }
    
}