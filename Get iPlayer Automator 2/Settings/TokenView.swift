//
//  TokenView.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 8/9/23.
//

import SwiftUI

struct TokenView: View {
    let title: String
    let action: (String) -> Void

    var body: some View {
        HStack(spacing: 5) {
            Button {
                action(title)
            } label: {
                Image(systemName: "x.circle")
            }
            .buttonStyle(.borderless)

            Text(title)
                .textCase(.uppercase)
        }
        .padding(.vertical, 4)
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .background {
            RoundedRectangle(cornerRadius: 30)
                .fill(Color(.lightGray))
        }
    }

}

#Preview {
    TokenView(title: "fhd") { title in
        print("\(title) clicked")
    }
}

