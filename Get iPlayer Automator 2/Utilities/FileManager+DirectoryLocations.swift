//
//  FileManager+DirectoryLocations.swift
//
//  Created by Scott Kovatch on 8/3/23.
//

import Foundation
import CocoaLumberjackSwift

extension FileManager {

    //
    //
    // applicationSupportDirectory
    //
    // Returns the path to the applicationSupportDirectory (creating it if it doesn't
    // exist).
    //
    var applicationSupportDirectory: String
    {
        var appSupportDir = URL.applicationSupportDirectory
        if let executableName = Bundle.main.infoDictionary?["CFBundleExecutable"] as? String {

#if DEBUG
            let dirName = executableName.appending("_debug")
#else
            let dirName = executableName
#endif
            appSupportDir.append(component: dirName, directoryHint: .isDirectory)
            do {
                try createDirectory(at: appSupportDir, withIntermediateDirectories: true)
            } catch {
                DDLogError("Unable to find or create application support directory: \(error)\n")
            }

            return appSupportDir.path(percentEncoded: false)
        } else {
            return "~/.get_iplayer"
        }
    }
}
