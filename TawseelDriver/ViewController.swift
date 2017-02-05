//
//  ViewController.swift
//  TawseelDriver
//
//  Created by Mahmoud Amer on 1/29/17.
//  Copyright © 2017 Tawseel. All rights reserved.
//

import UIKit
import Firebase
import CoreLocation

class ViewController: UIViewController {
    
    
    var ref: FIRDatabaseReference!
    // currentTripKey will hold started trip key
    var currentTripKey = ""
    var timer = Timer()
    var counter:Int = 0
    
    var locationManager = CLLocationManager()
    // locationManager coordinate to hold current location and send every 5 seconds
    var locCurrentValueValue = CLLocationCoordinate2D()
    // Bool indicating whether trip running or not
    var tripStarted = false
    //Locations Array
    var locationsArray = [String]()
    
    
    @IBOutlet weak var endTripBtn: UIButton!
    @IBOutlet weak var startTripBtn: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Disable end trip button, Enable when trip started
        self.endTripBtn.isEnabled = false
        
        // Database reference object
        ref = FIRDatabase.database().reference()
        
        // Ask for Authorisation from the User.
        self.locationManager.requestAlwaysAuthorization()
        self.locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.requestAlwaysAuthorization()
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
        if tripStarted == true {
            // For test reasons, We'll end the trip when app closed.
            self.EndTrip(self.endTripBtn)
            super.viewWillDisappear(animated)
        }
        
    }
    
    /* Start a new trip action */
    @IBAction func startATrip(_ sender: UIButton) {
        //Empty Locations Array
        locationsArray.removeAll()
        // Set tripStarted to true to indicate that a trip is running
        tripStarted = true
        //Insert new trip record to firebase and hold the inserted key in variable (currentTripKey)
        currentTripKey = ref.child("trips").childByAutoId().key
        let trip = ["status": "started",
                    "cost": "nothing",
                    "locations" : "0"]
        let childUpdates = ["/trips/\(currentTripKey)": trip]
        ref.updateChildValues(childUpdates)
        
        // Reset timer
        timer.invalidate()
        // Start new timer for the new trip
        timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(timerAction), userInfo: nil, repeats: true)
        
        //UI Staff
        self.startTripBtn.isEnabled = false
        self.endTripBtn.isEnabled = true
    }
    /* End trip action */
    @IBAction func EndTrip(_ sender: UIButton) {
        
        // Reset timer
        timer.invalidate()
        
        // Change trip status to ended (Cost will be updated by firebase queue)
        ref.child("trips/\(currentTripKey)/status").setValue("ended")
        
        //Prepare the task for Firebase Queue
        let trip = ["tripID": currentTripKey, "locations" : locationsArray] as [String : Any]
        print(trip)
        
        let jsonData = try? JSONSerialization.data(withJSONObject: trip)
        
        // create post request
        let url = URL(string: "https://tawseel-b2ded.firebaseio.com/queue/tasks.json")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // insert json data to the request
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            let responseJSON = try? JSONSerialization.jsonObject(with: data, options: [])
            if let responseJSON = responseJSON as? [String: Any] {
                print(responseJSON)
            }
        }
        
        task.resume()
        
        // UI Staff
        self.startTripBtn.isEnabled = true
        self.endTripBtn.isEnabled = false
        
        // Set tripStarted to false to indicate that trip ended
        tripStarted = false
    }
    
    // Triggered every 5 seconds to update driver location
    func timerAction() {
        //Get integer timestamp
        let timestamp = Int(NSDate.timeIntervalSinceReferenceDate*1000)  //Unique
        ref.child("trips/\(currentTripKey)/locations").child(String(timestamp)).setValue("\(locCurrentValueValue.latitude),\(locCurrentValueValue.longitude)")
        
        //Update Locations Array
        locationsArray.append("\(locCurrentValueValue.latitude),\(locCurrentValueValue.longitude)")
        print(locationsArray)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
// MARK: - Location Manager Delegate
extension ViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Monitoring failed for region with identifier: \(region!.identifier)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location Manager failed with the following error: \(error)")
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locCurrentValueValue = (manager.location?.coordinate)!
    }
    
}
