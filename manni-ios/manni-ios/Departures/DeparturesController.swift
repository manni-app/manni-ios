//
//  DeparturesController.swift
//  manni-ios
//
//  Created by yaaarrrnnn on 03.02.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import Foundation
import DVB
import Motion
import Material
import CoreLocation

class DeparturesController: ViewController {
    
    public var stop: Stop? {
        didSet {
            guard let stop = stop else {return}
            loadDepartures()
            
            stopNameLabel.text = stop.name
            stopLocationLabel.text = stop.region ?? "Dresden"
        }
    }
    
    public var location: CLLocation? {
        didSet {
            if let location = location, let distance = stop?.approximateDistance(from: location) {
                let distanceStr = distance > 1000 ? "\(distance / 1000) km" : "\(distance) m"
                stopLocationLabel.text = "\(distanceStr) entfernt, in \(stop?.region ?? "Dresden")"
            }
        }
    }
    
    public var programmaticDismissDelegate: ProgrammaticDismissDelegate?
    
    fileprivate var showsLoading: Bool = true {
        didSet {
            let value = showsLoading
            DispatchQueue.main.async {
                guard value == self.showsLoading else {return}
                UIView.transition(with: self.collectionView, duration: 0.2, options: .transitionCrossDissolve, animations: {self.collectionView.reloadData()}, completion: nil)
            }
        }
    }
    
    fileprivate var departures = [Departure]()
    fileprivate var scheduledTimer: Timer?
    
    fileprivate let gradientLayer = CAGradientLayer()
    fileprivate let backButton = SkeuomorphismIconButton(image: Icon.arrowBack, tintColor: Color.grey.darken4)
    fileprivate let stopNameLabel = UILabel()
    fileprivate let stopLocationLabel = UILabel()
    fileprivate let collectionView = CollectionView()
    fileprivate let flowLayout = UICollectionViewFlowLayout()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor("#ECE9E6")
        
        prepareBackground()
        prepareBackButton()
        prepareStopNameLabel()
        prepareStopLocationLabel()
        prepareCollectionView()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        scheduledTimer?.invalidate()
    }
    
    @objc func backButtonTouched() {
        self.dismiss(animated: true)
        self.programmaticDismissDelegate?.willDismissProgrammatically()
    }
    
    @objc func loadDepartures() {
        guard let stop = stop else {return}
        
        // Do not set showsLoading to true here,
        // to create a seamless experience when
        // dynamically reloading departures.
        // The load animation should only be
        // shown, when the controller is opened first.
        
        Departure.monitor(
            stopWithId: stop.id,
            dateType: .departure
        ) {
            result in
            guard let success = result.success else {return}
            self.departures = success.departures
            
            self.showsLoading = false
            
            // Schedule next departure load
            self.scheduledTimer?.invalidate()
            self.scheduledTimer = Timer(fireAt: success.expirationTime, interval: 0, target: self, selector: #selector(self.loadDepartures), userInfo: nil, repeats: false)
            RunLoop.main.add(self.scheduledTimer!, forMode: .common)
        }
    }
}

extension DeparturesController {
    fileprivate func prepareBackground() {
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.colors = Gradients.clouds.map {$0.cgColor}
        gradientLayer.frame = view.bounds
        view.layer.addSublayer(gradientLayer)
    }
    
    fileprivate func prepareBackButton() {
        view.layout(backButton)
            .topSafe(24)
            .left(24)
            .height(64)
            .width(64)
        backButton.skeuomorphismView.lightShadowOpacity = 0.3
        backButton.skeuomorphismView.darkShadowOpacity = 0.2
        backButton.pulseColor = Color.blue.base
        backButton.addTarget(self, action: #selector(backButtonTouched), for: .touchUpInside)
        backButton.transition(.fadeIn)
    }
    
    fileprivate func prepareStopNameLabel() {
        view.layout(stopNameLabel)
            .below(backButton, 24)
            .left(24)
            .right(24)
            .height(32)
        stopNameLabel.font = RobotoFont.bold(with: 24)
        stopNameLabel.textColor = Color.grey.darken4
        stopNameLabel.numberOfLines = 1
        stopNameLabel.transition(.fadeIn)
    }
    
    fileprivate func prepareStopLocationLabel() {
        view.layout(stopLocationLabel)
            .below(stopNameLabel, 8)
            .left(24)
            .height(32)
            .right(24)
        stopLocationLabel.font = RobotoFont.light(with: 18)
        stopLocationLabel.textColor = Color.grey.darken4
        stopLocationLabel.numberOfLines = 1
        stopLocationLabel.transition(.fadeIn)
    }
    
    fileprivate func prepareCollectionView() {
        view.layout(collectionView)
            .below(stopLocationLabel, 12)
            .left(0)
            .right(0)
            .height(238)
        flowLayout.estimatedItemSize = .init(width: 148, height: 256)
        flowLayout.scrollDirection = .horizontal
        collectionView.contentInset = .init(top: 0, left: 24, bottom: 0, right: 24)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.collectionViewLayout = flowLayout
        collectionView.register(DepartureCollectionViewCell.self, forCellWithReuseIdentifier: DepartureCollectionViewCell.identifier)
        collectionView.transition(.fadeIn)
    }
    
}

extension DeparturesController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if showsLoading {
            return 5
        }
        return departures.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DepartureCollectionViewCell.identifier, for: indexPath) as! DepartureCollectionViewCell
        if showsLoading {
            cell.departure = nil
        } else {
            cell.departure = departures[indexPath.row]
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard
            !showsLoading,
            let stop = self.stop
        else {return}
        let departure = departures[indexPath.row]
        let controller = TripController()
        controller.departure = departure
        controller.stop = stop
        present(controller, animated: true)
    }
    
}
