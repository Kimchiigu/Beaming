//
//  ContentView.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 02/07/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Let's Discuss")
                .font(.title)
                .bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        
        Spacer()
    }
}

#Preview {
    ContentView()
}
