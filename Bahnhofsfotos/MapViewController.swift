//
//  MapViewController.swift
//  Bahnhofsfotos
//
//  Created by Miguel Dönicke on 17.12.16.
//  Copyright © 2016 MrHaitec. All rights reserved.
//

import AKSideMenu
import CoreLocation
import FBAnnotationClusteringSwift
import FontAwesomeKit_Swift
import MapKit
import SwiftyUserDefaults
import UIKit

class MapViewController: UIViewController {

  var locationManager: CLLocationManager?
  var stationsUpdatedAt: Date?
  var clusteringIsActive = true

  lazy var clusteringManager: FBClusteringManager = {
      let renderer = FBRenderer(animator: FBBounceAnimator())
      return FBClusteringManager(algorithm: FBAllMapDistanceBasedClusteringAlgorithm(), renderer: renderer)
  }()

  fileprivate lazy var configuration: FBAnnotationClusterViewConfiguration = {
    let color = Helper.tintColor

    var smallTemplate = FBAnnotationClusterTemplate(range: Range(uncheckedBounds: (lower: 0, upper: 6)), displayMode: .SolidColor(sideLength: 25, color: color))
    smallTemplate.borderWidth = 2
    smallTemplate.font = UIFont.boldSystemFont(ofSize: 13)

    var mediumTemplate = FBAnnotationClusterTemplate(range: Range(uncheckedBounds: (lower: 6, upper: 15)), displayMode: .SolidColor(sideLength: 35, color: color))
    mediumTemplate.borderWidth = 3
    mediumTemplate.font = UIFont.boldSystemFont(ofSize: 13)

    var largeTemplate = FBAnnotationClusterTemplate(range: nil, displayMode: .SolidColor(sideLength: 45, color: color))
    largeTemplate.borderWidth = 4
    largeTemplate.font = UIFont.boldSystemFont(ofSize: 13)

    return FBAnnotationClusterViewConfiguration(templates: [smallTemplate, mediumTemplate], defaultTemplate: largeTemplate)
  }()

  @IBOutlet weak var mapView: MKMapView!
  @IBOutlet weak var trackingButton: UIButton!
  @IBOutlet weak var toggleClusteringButton: UIButton!

  @IBAction func showMenu(_ sender: Any) {
    sideMenuViewController?.presentLeftMenuViewController()
  }

  @IBAction func followUser(_ sender: Any) {
    mapView.setUserTrackingMode(.follow, animated: true)
  }

  @IBAction func toggleClustering(_ sender: Any) {
    view.makeToastActivity(.center)

    if clusteringIsActive {
      clusteringManager.removeAll(from: mapView)
      mapView.addAnnotations(StationStorage.stations.map { StationAnnotation(station: $0) })
      toggleClusteringButton.fa_setTitle(.fa_map_marker, for: .normal)
    } else {
      mapView.removeAnnotations(mapView.annotations)
      clusteringManager.replace(annotations: StationStorage.stations.map { StationAnnotation(station: $0) }, in: mapView)
      toggleClusteringButton.fa_setTitle(.fa_map_pin, for: .normal)
    }

    clusteringIsActive = !clusteringIsActive
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    Helper.rootViewController?.delegate = self

    locationManager = CLLocationManager()
    locationManager?.delegate = self
    locationManager?.desiredAccuracy = kCLLocationAccuracyHundredMeters
    locationManager?.requestWhenInUseAuthorization()
    locationManager?.startUpdatingLocation()

    showStations()
  }

  // Bahnhöfe anzeigen
  func showStations() {
    if StationStorage.lastUpdatedAt != stationsUpdatedAt {
      stationsUpdatedAt = StationStorage.lastUpdatedAt
      clusteringManager.replace(annotations: StationStorage.stations.map { StationAnnotation(station: $0) }, in: mapView)
    }
  }

}

// MARK: - MKMapViewDelegate
extension MapViewController: MKMapViewDelegate {

  func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
    clusteringManager.updateAnnotations(in: mapView)
  }

  func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
    guard let annotation = view.annotation as? FBAnnotationCluster else { return }

    var region = annotation.region

    // Make span a bit bigger so there are no points on the edges of the map
    let smallSpan = region.span
    region.span = MKCoordinateSpan(latitudeDelta: smallSpan.latitudeDelta * 1.3, longitudeDelta: smallSpan.longitudeDelta * 1.3)

    mapView.setRegion(region, animated: true)
  }

  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    if annotation is MKUserLocation {
      return nil
    }

    var reuseId = "Pin"

    // check if cluster
    if annotation is FBAnnotationCluster {
      reuseId = "Cluster"
      let clusterView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) ??
        FBAnnotationClusterView(annotation: annotation, reuseIdentifier: reuseId, configuration: configuration)
      clusterView.annotation = annotation
      return clusterView
    }

    // button for navigation
    let button = UIButton(type: .system)
    button.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
    button.fa_setTitle(.fa_compass, for: .normal)

    // single station
    let pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView ??
      MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)

    pinView.annotation = annotation
    pinView.isEnabled = true
    pinView.canShowCallout = true
    pinView.rightCalloutAccessoryView = button
    pinView.pinTintColor = Helper.tintColor

    if let annotation = annotation as? StationAnnotation {
      if annotation.station.photographer != nil && Defaults[.accountName] != nil {
        if annotation.station.photographer!.lowercased() == Defaults[.accountName]!.lowercased() {
          pinView.pinTintColor = Helper.blueColor
        } else {
          pinView.pinTintColor = Helper.greenColor
        }
      }
    }

    return pinView
  }

  func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
    if let annotation = view.annotation as? StationAnnotation {
      Helper.openNavigation(to: annotation.station)
    } else if let annotation = view.annotation as? Station {
      Helper.openNavigation(to: annotation)
    }
  }

  func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
    UIView.animate(withDuration: 0.4, animations: {
      self.trackingButton.alpha = mode == .follow ? 0.0 : 1.0
    })
  }

  func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
    view.hideToastActivity()
  }

}

// MARK: - CLLocationManagerDelegate
extension MapViewController: CLLocationManagerDelegate {

  func locationManager(_ manager: CLLocationManager, didUpdateLocations _: [CLLocation]) {
    mapView.setUserTrackingMode(.follow, animated: true)
    manager.stopUpdatingLocation()
  }

}

// MARK: - AKSideMenuDelegate
extension MapViewController: AKSideMenuDelegate {

  func sideMenu(_ sideMenu: AKSideMenu, willHideMenuViewController menuViewController: UIViewController) {
    showStations()
  }

}
