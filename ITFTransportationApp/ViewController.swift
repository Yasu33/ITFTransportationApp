//
//  ViewController.swift
//  ITFTransportationApp
//
//  Created by Yasuko Namikawa on 2019/03/08.
//  Copyright © 2019年 Yasuko Namikawa. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import Firebase

class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, UIPickerViewDelegate, UIPickerViewDataSource, UIApplicationDelegate {
    
    // 地図
    @IBOutlet var myMapView: MKMapView!
    
    // 位置情報
    var myLocationManager: CLLocationManager!
    
    // 最新の一個前の位置情報
    var formerLocation: CLLocation = CLLocation()
    
    // formerLocationからnewLocationまでの距離
    var distance: Double!
    
    // Firebase Database
    var db: Firestore!
    var ref: DocumentReference? = nil
    
    // バスの種類
    let busRoute: [String] = [
        "大学循環右回り", "大学循環左回り", "大学中央行", "土浦駅西口行", "ひたち野うしく駅行", "荒川沖駅西口行"
    ]
    
    // 選択されたバス
    var selectedBus: String!
    
    // pickerview
    @IBOutlet var pickerView: UIPickerView!
    
    // userDocumentID
    var userDocumentID: String!
    
    // 通信中のバスの位置のピン
    var annotation = [MKPointAnnotation]()
    
    // 現在通信中のバスの位置
    var realtimeBusLocations = [[Double]]()
    
    var ridingSwitch : Bool = false
    
    @IBOutlet var button: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        db = Firestore.firestore()
        
        myLocationManager = CLLocationManager()
        myLocationManager.delegate = self
        
        myMapView.delegate = self
        
        pickerView.delegate = self
        pickerView.dataSource = self
        
        // 地図の表示範囲を設定
        let initialCoordinate = CLLocationCoordinate2DMake(36.101, 140.1033)
        let span = MKCoordinateSpan.init(latitudeDelta: 0.038, longitudeDelta: 0.029)
        let region = MKCoordinateRegion(center: initialCoordinate, span: span)
        
        // 地図の表示
        myMapView.setRegion(region, animated: true)
        
        // 位置情報がオンになっているか
        print(CLLocationManager.locationServicesEnabled())
        
        myLocationManager.allowsBackgroundLocationUpdates = true
        myLocationManager.requestAlwaysAuthorization()
        
        // 位置情報取得の許可
        if(CLLocationManager.locationServicesEnabled() == true){
            
            // 現在の許可の状態で場合分け
            switch CLLocationManager.authorizationStatus() {
            //未設定の場合
//            case CLAuthorizationStatus.notDetermined:
//                myLocationManager.requestWhenInUseAuthorization()
                
            //機能制限されている場合
            case CLAuthorizationStatus.restricted:
                alertMessage(message: "位置情報サービスの利用が制限されている利用できません。「設定」⇒「一般」⇒「機能制限」")
                
            //「許可しない」に設定されている場合
            case CLAuthorizationStatus.denied:
                alertMessage(message: "位置情報の利用が許可されていないため利用できません。「設定」⇒「プライバシー」⇒「位置情報サービス」⇒「バスどこ」")
                
            // 「常に許可」か「使用中のみ許可」の場合
            default:
                break
            }
            
        } else {
            //位置情報サービスがOFFの場合
            alertMessage(message: "位置情報サービスがONになっていないため利用できません。「設定」⇒「プライバシー」⇒「位置情報サービス」")
        }
        
        // FirebaseのDatabaseに変更があった時の処理
        db.collection("Bus").addSnapshotListener(includeMetadataChanges: true) {(snapShot, error) in
            guard let value = snapShot else {
                print("snapShot is nil")
                return
            }
            
            // バスの位置を表示
            self.pointLocations()
            
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationWillTerminate(_:)), name: UIApplication.willTerminateNotification, object: nil)
    }
    
    // アプリが終了した時
    func applicationWillTerminate(_ application: UIApplication) {
        print("finish!!")
        button.setBackgroundImage(UIImage(named: "ride.png"), for: .normal)
        //位置情報の更新やめる
        if userDocumentID != nil {
            myLocationManager.stopUpdatingLocation()
            db.collection("Bus").document(userDocumentID).delete()
            userDocumentID = nil
        }
        ridingSwitch = false
    }
    
    //メッセージ出力メソッド
    func alertMessage(message:String) {
        let aleartController = UIAlertController(title: "注意", message: message, preferredStyle: .alert)
        let defaultAction = UIAlertAction(title:"OK", style: .default, handler:nil)
        aleartController.addAction(defaultAction)
        
        present(aleartController, animated:true, completion:nil)
    }
    
    // button
    @IBAction func buttonAction() {
        if ridingSwitch {
            button.setBackgroundImage(UIImage(named: "ride.png"), for: .normal)
            //位置情報の更新やめる
            if userDocumentID != nil {
                myLocationManager.stopUpdatingLocation()
                db.collection("Bus").document(userDocumentID).delete()
                userDocumentID = nil
            }
            ridingSwitch = false
        }else{
            button.setBackgroundImage(UIImage(named: "getoff.png"), for: .normal)
            if CLLocationManager.locationServicesEnabled() {
                // 位置情報更新し始める
                myLocationManager.startUpdatingLocation()
                // pickerviewで選択されたバス
                selectedBus = busRoute[pickerView.selectedRow(inComponent: 0)]
                print(selectedBus!)
            }
            ridingSwitch = true
        }
    }
    
    // 位置情報が更新された時に呼ばれるメソッド
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = manager.location {
            
//            print("緯度：\(location.coordinate.latitude)")
//            print("経度：\(location.coordinate.longitude)")
//            print(location.coordinate)
            
            // 最新の位置情報
            guard let newLocation = locations.last,
                CLLocationCoordinate2DIsValid(newLocation.coordinate) else {
                    return
            }
            
            // 移動距離
            distance = newLocation.distance(from: formerLocation)
//            print("distance:\(String(distance))")
            
            // 前の書き込み位置から20m進んだらFirebaseに最新の位置を書き込み
            if distance > 0 {
                
                // Firebase
                let data = [
                    "Bus": selectedBus!,
                    "latitude": location.coordinate.latitude,
                    "longitude": location.coordinate.longitude,
                    "createdAt": FieldValue.serverTimestamp()
                    ] as [String : Any]
                
                if userDocumentID == nil {
                    ref = db.collection("Bus").addDocument(data: data){ err in
                        if let err = err {
                            print("Error adding document: \(err)")
                        } else {
//                            print("Document added with ID: \(self.ref!.documentID)")
                        }
                    }
                    userDocumentID = self.ref!.documentID
                }else{
                    db.collection("Bus").document(userDocumentID).updateData(data)
                }
                
                // 最新の位置情報を一個前にずらす
                formerLocation = newLocation
                
            }
            
        }
        
    }
    
    // mapのピンの画像を変える
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if (annotation is MKUserLocation) {
            // ユーザの現在地の青丸マークは置き換えない
            return nil
        } else {
            // CustomAnnotationの場合に画像を配置
            let identifier = "Pin"
            var annotationView: MKAnnotationView? = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotationView == nil {
                annotationView = MKAnnotationView.init(annotation: annotation, reuseIdentifier: identifier)
            }
            
            annotationView?.image = UIImage.init(named: "bus.png") // 任意の画像名
            annotationView?.annotation = annotation
            annotationView?.canShowCallout = true  // タップで吹き出しを表示
            return annotationView
        }
    }
    
    // UIPickerView
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return busRoute.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return busRoute[row]
    }
    
    // 通信して地図上にピンを置くメソッド
    func pointLocations() {
        
        self.db.collection("Bus").getDocuments () { (querySnapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            } else {
                // realtimeBusLocaionsの中身を全消去
                self.realtimeBusLocations.removeAll()
                // 一度map上のピンを全消去
                self.myMapView.removeAnnotations(self.annotation)
                // annotationの中身を全消去
                self.annotation.removeAll()
                // 現在データベースに送られている位置情報を配列に入れる
                for document in querySnapshot!.documents {
//                    print("\(document.documentID) => \(document.data())")
                    self.realtimeBusLocations.append([document.data()["latitude"] as! Double, document.data()["longitude"] as! Double])
                    self.annotation.append(MKPointAnnotation())
                }
                
//                print(self.realtimeBusLocations)
                if self.realtimeBusLocations.count > 0 {
                    for i in 0...(self.realtimeBusLocations.count - 1) {
                        //database中に記録されている位置にピンを立てる
                        self.annotation[i].coordinate = CLLocationCoordinate2DMake(self.realtimeBusLocations[i][0], self.realtimeBusLocations[i][1])
                        self.myMapView.addAnnotation(self.annotation[i])
                    }
                }
                
            }
        }
    }
    
}

