//
//  MeetingView.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 02/07/26.
//

import SwiftUI

struct MeetingView: View {
    var body: some View {
        VStack {
            HStack {
                Text("Chris's Room")
                    .font(.title)
                    .bold()
                
                Spacer()
                
                Text("6/8")
                    .font(.title3)
            }
            
            Divider()
            
            List {
                Text("Christopher Hardy Gunawan")
                Text("Axel Nino Nakata")
                Text("Muhammad Fadhil Abidin")
                Text("Muhammad Nafriel Ramadhan")
                Text("Ananta Ghaisani")
                Text("Ulfa Chairul")
            }
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .padding(.bottom, 16)
            
            HStack {
                // end call
                Button {
                    
                } label: {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 24))
                        .padding(24)
                }
                .glassEffect()
                .buttonBorderShape(.circle)
                
                // mute/unmute
                Button {
                    
                } label: {
                    Image(systemName: "microphone.fill")
                        .font(.system(size: 36))
                        .padding(36)
                }
                .glassEffect()
                .buttonBorderShape(.circle)
                
                // leave call
                Button {
                    
                } label: {
                    Image(systemName: "door.left.hand.open")
                        .font(.system(size: 24))
                        .padding(24)
                }
                .glassEffect()
                .buttonBorderShape(.circle)
            }
        }
        .padding(16)
    }
}

#Preview {
    MeetingView()
}
