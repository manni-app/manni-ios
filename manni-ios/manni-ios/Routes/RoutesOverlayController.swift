//
//  RoutesOverlayController.swift
//  manni-ios
//
//  Created by It's free real estate on 27.02.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import Foundation
import Material
import DVB


protocol RoutesOverlayControllerDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView)
    func scrollView(
        _ scrollView: UIScrollView,
        willEndScrollingWithVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    )
}

protocol RouteSelectionDelegate {
    func didSelect(route: Route)
}


class RoutesOverlayController: ViewController {
    
    public var endpoints: (Stop, Stop)?
    
    fileprivate var routes = [Route]()
    fileprivate var lastFetchedDate: Date?
    
    public var overlayDelegate: RoutesOverlayControllerDelegate?
    public var routeSelectionDelegate: RouteSelectionDelegate?
    
    private(set) lazy var tableView = TableView(frame: .zero, style: .grouped)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .clear
        view.layout(tableView)
            .edges()
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.showsVerticalScrollIndicator = false
        tableView.register(RouteOverviewCell.self, forCellReuseIdentifier: RouteOverviewCell.reuseIdentifier)
        tableView.layer.cornerRadius = 32
        tableView.backgroundColor = Color.grey.lighten3

        loadRoutes(startingAt: Date())
    }
    
    func loadRoutes(startingAt time: Date) {
        guard let endpoints = endpoints else {return}
        lastFetchedDate = time
        Route.find(fromWithID: endpoints.0.id, toWithID: endpoints.1.id, time: time) {
            result in
            guard let success = result.success else {
                DispatchQueue.main.async {
                    if #available(iOS 10.0, *) {
                        UINotificationFeedbackGenerator()
                            .notificationOccurred(.error)
                    }
                    let alert = UIAlertController(title: "VVO-Schnittstelle nicht erreichbar oder es wurden keine (weiteren) Routen gefunden.", message: "Bitte versuche es später erneut.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .cancel) {
                        _ in
                        self.dismiss(animated: true)
                    })
                    alert.addAction(UIAlertAction(title: "Erneut versuchen", style: .default, handler: {
                        _ in
                        self.loadRoutes(startingAt: time)
                    }))
                    self.present(alert, animated: true, completion: nil)
                }
                return
            }
            if #available(iOS 10.0, *) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            
            for route in success.routes {
                var isContained = false
                for containedRoute in self.routes {
                    if  containedRoute.departureTime == route.departureTime,
                        containedRoute.modeChain == route.modeChain {
                        isContained = true
                        break
                    }
                }
                if isContained {
                    continue
                }
                self.routes.append(route)
            }
            
            self.routes.sort {$0.departureTime < $1.departureTime}
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
}

internal extension Route {
    var departureTime: Date {
        get {
            return partialRoutes.first?.regularStops?.first?.departureTime ?? Date()
        }
    }
}

extension RoutesOverlayController: UITableViewDelegate, UITableViewDataSource {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        overlayDelegate?.scrollViewDidScroll(scrollView)
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        overlayDelegate?.scrollView(
            scrollView,
            willEndScrollingWithVelocity: velocity,
            targetContentOffset: targetContentOffset
        )
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 24
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        let handle = UIView()
        handle.backgroundColor = Color.grey.base
        handle.layer.cornerRadius = 3
        view.layout(handle).width(32).height(6).top(10).centerX()
        return view
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return routes.count + 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 108
    }
    
    func indexPathHitsLoadingCell(_ indexPath: IndexPath) -> Bool {
        if routes.count == 0 {
            return true
        }
        return indexPath.row > routes.count - 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RouteOverviewCell.reuseIdentifier, for: indexPath) as! RouteOverviewCell
        if indexPathHitsLoadingCell(indexPath) {
            cell.prepare(for: nil)
        } else {
            cell.prepare(for: routes[indexPath.row])
        }
        cell.delegate = self
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !indexPathHitsLoadingCell(indexPath) else {return}
        let route = routes[indexPath.row]
        didSelect(route: route)
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        // Only if the mocked loading cell is shown
        // it is necessary to take further action
        guard indexPathHitsLoadingCell(indexPath) else {return}
        
        // If there are no fetched routes and there is
        // currently no fetch running, schedule one
        if routes.isEmpty && lastFetchedDate == nil {
            loadRoutes(startingAt: Date())
            return
        }
        
        // If there are fetched routes, fetch all
        // routes that are later than the last route
        if
            !routes.isEmpty,
            let lastDepartureDate = routes.last?.departureTime,
            lastDepartureDate != lastFetchedDate
        {
            loadRoutes(startingAt: lastDepartureDate)
        }
    }
    
}

extension RoutesOverlayController: RouteOverviewCellDelegate {    
    func didSelect(route: Route) {
        guard let index = routes.firstIndex(of: route) else {return}
        tableView.scrollToRow(at: IndexPath(row: index, section: 0), at: .top, animated: true)
        
        routeSelectionDelegate?.didSelect(route: route)
    }
}
