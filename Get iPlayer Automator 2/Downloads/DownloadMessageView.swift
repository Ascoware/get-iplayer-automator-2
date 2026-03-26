//
//  DownloadMessageView.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 9/17/23.
//

import SwiftUI

struct DownloadMessageView: View {
    var program: Programme

    var body: some View {
        Text(program.progress)
    }
}
