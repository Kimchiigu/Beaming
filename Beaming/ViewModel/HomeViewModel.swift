//
//  HomeViewModel.swift
//  Beaming
//
//  Created by Axel Nino Nakata on 02/07/26.
//

import Foundation
import Observation

@Observable
class HomeViewModel {
    var currentUser: User = User(name: "Axel", role: .hearing)
    var availableRooms: [Room] = []
    var showAlert: Bool = false
    var alertMessage: String = ""
    
    func loadDummyData() {
        let bob = User(name: "Bob", role: .deaf)
        let jesslyn = User(name: "Jesslyn", role: .hearing)
        let muffin = User(name: "Muffin", role: .hearing)
        let chris = User(name: "Christopher", role: .hearing)
        let kevin = User(name: "Kevin", role: .hearing)
        let sonnet = User(name: "Sonnet", role: .hearing)
        let fable = User(name: "Fable", role: .hearing)
        let stuart = User(name: "Stuart", role: .hearing)
        
        let room1 = Room(
            id: UUID(),
            isHost: chris,
            guests: [jesslyn, muffin, chris]
        )
        
        let room2 = Room(
            id: UUID(),
            isHost: jesslyn,
            guests: []
        )
        
        let room3 = Room(
            id: UUID(),
            isHost: bob,
            guests: [jesslyn, muffin, chris, kevin, sonnet, fable, stuart]
        )
        
        self.availableRooms = [room1, room2, room3]
    }
    
    func joinRoom(room: Room) {
        if room.capacity == 8{
            alertMessage = "Room is full"
            showAlert = true
            return
        }
        
        for i in 0..<availableRooms.count {
            if availableRooms[i].id == room.id {
                availableRooms[i].guests.append(currentUser)
                availableRooms[i].capacity = availableRooms[i].guests.count + 1
                
                alertMessage = "Successfully joined \(room.name)!"
                showAlert = true
            }
        }
    }
    
    func createRoom (){
        let newRoom = Room(id: UUID(), isHost: currentUser, guests: [])
        availableRooms.append(newRoom)
        alertMessage = "\(newRoom.name) created successfully!"
        showAlert = true
    }
}
