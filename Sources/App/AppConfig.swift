//
//  File.swift
//  
//
//  Created by Finer  Vine on 2022/1/22.
//

import Foundation
import Vapor

struct AppConfig {
    
    let aliPdsSecret: String
    let driveId: String
    var pdsAbsoluteFolderPath: String
    
    /*
     touch .env
     echo "ALI_PDS_SECRET=bcaaaaaaaaaaaaaaaaaaaaaaaaaaaac" >> .env
     echo "ALI_PDS_DRIVEID=51111110" >> .env
     echo "ALI_PDS_FOLDERPATH=pdsfolder" >> .env
     */
    static var environment: AppConfig {
        guard let pdsSecret = Environment.get("ALI_PDS_SECRET"),
              let driveId = Environment.get("ALI_PDS_DRIVEID") else {
                  return .init(aliPdsSecret: "", driveId: "", pdsAbsoluteFolderPath: "")
        }
        
        return .init(aliPdsSecret: pdsSecret,
                     driveId: driveId,
                     pdsAbsoluteFolderPath: Environment.get("ALI_PDS_FOLDERPATH") ?? "")
    }
}

extension Application {
    struct AppConfigKey: StorageKey {
        typealias Value = AppConfig
    }
    
    var config: AppConfig {
        get {
            storage[AppConfigKey.self] ?? .environment
        }
        set {
            storage[AppConfigKey.self] = newValue
        }
    }
}
