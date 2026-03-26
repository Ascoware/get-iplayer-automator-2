//
//  LogView.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 8/6/23.
//

import SwiftUI

struct LogView: View {

    var logger: LogController

    @State private var handle = ScrollingTextView.Handle()

    var body: some View {
        VStack(spacing: 0) {
            ScrollingTextView(entries: logger.entries, clearID: logger.clearID, handle: handle)

            HStack {
                Button("Copy to Clipboard") {
                    let pb = NSPasteboard.general
                    pb.declareTypes([.string], owner: nil)
                    pb.setString(handle.plainText, forType: .string)
                }.padding(10)
                Button("Clear") {
                    logger.clear()
                }.padding(10)
            }
            .controlSize(.large)
        }
    }
}

#Preview {
    LogView(logger: .init())
}
