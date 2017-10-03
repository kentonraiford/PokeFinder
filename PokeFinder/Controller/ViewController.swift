//
//  ViewController.swift
//  PokeFinder
//
//  Created by Kenton D. Raiford on 9/27/17.
//  Copyright © 2017 Kenton D. Raiford. All rights reserved.
//

import UIKit
import MapKit
import Firebase
import FirebaseDatabase
import GeoFire

class ViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!
    
    
    let locationManager = CLLocationManager()
    let locationRegion: CLLocationDistance = 2000
    var mapHasCenteredOnce = false
    var geoFire: GeoFire!
    var geoFireRef: DatabaseReference!
    
    
    override func viewDidAppear(_ animated: Bool)
    {
        locationAuthStatus()
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        setupDelegates()
        mapView.userTrackingMode = MKUserTrackingMode.follow //The map follows the user location.
        
        //initialize geoFire and geoFireRef
        geoFireRef = Database.database().reference()
        geoFire = GeoFire(firebaseRef: geoFireRef)

    }
    
    //Sets up all the delegates
    func setupDelegates()
    {
        mapView.delegate = self
    }
    
    
    
    
    /////////////
    // BUTTONS //
    /////////////
    
    //Adds a random Pokemon to the middle of the map
    @IBAction func spotRandomPokemon(_ sender: Any)
    {
        let loc = CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude) //center of the map
        let rand = arc4random_uniform(151) + 1 //using numbers as IDs for the pokemon
        createSighting(forLocation: loc, withPokemon: Int(rand))
    }
    
}


extension ViewController: MKMapViewDelegate, CLLocationManagerDelegate
{
    
    //Checks to see if the user has given us permission to track their location
    func locationAuthStatus()
    {
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse
        {
            mapView.showsUserLocation = true
        } else
        {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    //Shows the user's location when they've given us permission
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus)
    {
        if status == CLAuthorizationStatus.authorizedWhenInUse {
            mapView.showsUserLocation = true
        }
    }
    
    //Centers the map on the user's current location
    func centerMapOnLocation(location: CLLocation)
    {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, locationRegion, locationRegion)
        
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    //Everytime the map updates the users location
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation)
    {
        if let location = userLocation.location {
            if !mapHasCenteredOnce {
                centerMapOnLocation(location: location)
                mapHasCenteredOnce = true
            }
        }
    }
    
    //Whenever addAnnotation is called, viewFor will be called and display a graphic on the user's location. This function lets you customize the annotation before it's displayed on the map.
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView?
    {
        
        var annotationView: MKAnnotationView? //The visual representation of one of your annotation objects
        let userIdentifier = "User" //Used for user annotation
        let userAnnotationImg = UIImage(named: "ash")
        let annotationIdentifier = "Pokemon"
        
        if annotation.isKind(of: MKUserLocation.self)
        { //If this is a user location annotation, we want to change what's happening inside.
            
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: userIdentifier)
            annotationView?.image = userAnnotationImg
        } //Get pokemon annotation to drop on the app.
        else if let dequeAnnotation = mapView.dequeueReusableAnnotationView(withIdentifier: annotationIdentifier)
        {
            annotationView = dequeAnnotation
            annotationView?.annotation = annotation
        } else
        { //Incase the above Deque fails, we need to create a default annotation
            let av = MKAnnotationView(annotation: annotation, reuseIdentifier: annotationIdentifier)
            av.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            annotationView = av
        }
        
        //Make sure the annotationView is not nil and making sure we can cast this annotaiton as a PokeAnnotation
        if let annotationView = annotationView, let anno = annotation as? PokeAnnotation
        {
            annotationView.canShowCallout = true //If you use canShowCallout, you HAVE TO SET THE ANNOTATION TITLE or the app will crash without telling you why
            annotationView.image = UIImage(named: "\(anno.pokemonNumber)")
            let btn = UIButton()
            btn.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            btn.setImage(UIImage(named: "map"), for: .normal)
            annotationView.rightCalloutAccessoryView = btn
        }
        
        return annotationView
    }
    
    //Whenever the region changes the user pans, update the map with pokemon.
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool)
    {
        let loc = CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
        showSightinsOnMap(location: loc)
    }
    
    //When you tap on the pokemon, what's it going to do
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl)
    {
        
        if let anno = view.annotation as? PokeAnnotation {
            
            /* We are configuring our Apple Maps s when the user opens it, it looks nice. When working with Apple Maps you need a placemark, a placemark where you start and where you're going.
             */
            
            let place = MKPlacemark(coordinate: anno.coordinate) //Starting
            let destination = MKMapItem(placemark: place) //Destination
            destination.name = "Pokemon Sighting"
            
            let regionDistance: CLLocationDistance = 1000
            let regionSpan = MKCoordinateRegionMakeWithDistance(anno.coordinate, regionDistance, regionDistance) //How much of the map do you want to show
            
            let options = [MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: regionSpan.center), MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: regionSpan.span), MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving] as [String : Any]
            
            MKMapItem.openMaps(with: [destination], launchOptions: options)
            
        }
        
    }
    
    //Select pokemon we are going to list. Whenever we see a pokemon, it's going to call this function.
    func createSighting(forLocation location: CLLocation, withPokemon pokeId: Int)
    {
        geoFire.setLocation(location, forKey: "\(pokeId)") //pass in the location, pass in the key that references that location.
    }
    
    //When we get the user's location, we want to show where all the pokemon are.
    func showSightinsOnMap(location: CLLocation)
    {
        let circleQuery = geoFire!.query(at: location, withRadius: 2.5) //2.5 kilometers
        _ = circleQuery?.observe(GFEventType.keyEntered, with: //Key Entered: The location of a key now matches the query criteria. We are going to observe whenever it finds a sighting.
            { (key, location) in

                if let key = key, let location = location
                {
                    let anno = PokeAnnotation(coordinate: location.coordinate, pokemonNumber: Int(key)!) //passing the location of that specific pokemon. We are using Int(String) to get the number of the pokemon we want. The pokeNumber is what was saved when we called geoFire.setLocation.
                    self.mapView.addAnnotation(anno)
                }
        })
    }
    
}


