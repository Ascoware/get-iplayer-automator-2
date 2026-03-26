//
//  HTTPProxy.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 8/15/23.
//

import Foundation

struct HTTPProxy {

    let url: URL?

    init(url: URL?) {
        self.url = url
    }

    init(string: String)
    {
        if string.lowercased().hasPrefix("http://") || string.lowercased().hasPrefix("https://") {
            self.init(url: URL(string: string))
        } else {
            self.init(url: URL(string: "http://\(string)"))
        }
    }

    var type: CFString {
        if let scheme = url?.scheme,
           scheme.lowercased() == "https" {
            return kCFProxyTypeHTTPS
        } else {
            return kCFProxyTypeHTTP
        }
    }

    var host: String? {
        return url?.host
    }

    var port: Int {
        return url?.port ?? 0
    }

    var user: String? {
        return url?.user
    }

    var password: String? {
        return url?.password;
    }
}

