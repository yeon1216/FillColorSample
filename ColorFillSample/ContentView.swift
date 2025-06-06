//
//  ContentView.swift
//  ColorFillSample
//
//  Created by ksy on 6/6/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image("fill_img_1")
                .resizable()
                .renderingMode(.original)
                .frame(width: 300, height: 600)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
