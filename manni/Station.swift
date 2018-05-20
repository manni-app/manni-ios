//
//  CoordinateTools.swift
//  manni
//
//  Created by Philipp Matthes on 19.05.18.
//  Copyright © 2018 Philipp Matthes. All rights reserved.
//

import Foundation
import CoreLocation
import DVB

class Station {
    
    var id: String
    var nameWithLocation: String
    var name: String
    var location: String
    var wgs84Lat: Double
    var wgs84Long: Double
    
    init(
        id: String,
        nameWithLocation: String,
        name: String,
        location: String,
        wgs84Lat: Double,
        wgs84Long: Double
    ) {
        self.id = id
        self.nameWithLocation = nameWithLocation
        self.name = name
        self.location = location
        self.wgs84Lat = wgs84Lat
        self.wgs84Long = wgs84Long
    }
    
    static func loadAllStations() -> [Station] {
        var stationsCSV = CSV.csv(data: CSV.readDataFromCSV(fileName: "stations", fileType: "csv"))
        stationsCSV.removeFirst()
        
        var stations = [Station]()
        for csv in stationsCSV {
            if csv.count != 9 { continue }
            let id = csv[0]
            let nameWithLocation = csv[1]
            let name = csv[2]
            let location = csv[3]
            let wgs84Long = Double(csv[7].replacingOccurrences(of: ",", with: "."))!
            let wgs84Lat = Double(csv[8].replacingOccurrences(of: ",", with: "."))!
            stations.append(Station(id: id, nameWithLocation: nameWithLocation, name: name, location: location, wgs84Lat: wgs84Lat, wgs84Long: wgs84Long))
        }
        
        return stations
    }
    
    static func nearestStations(coordinate wgs: WGSCoordinate) -> [Station] {
        let stationsSorted = loadAllStations().sorted {
            $0.distance(wgs) < $1.distance(wgs)
        }
        return stationsSorted
    }
    
    func asCLL() -> CLLocation {
        return CLLocation(latitude: self.wgs84Lat, longitude: self.wgs84Long)
    }
    
    func distance(_ wgs: WGSCoordinate) -> Double {
        return asCLL().distance(from: CLLocation(latitude: wgs.latitude, longitude: wgs.longitude))
    }
    
}