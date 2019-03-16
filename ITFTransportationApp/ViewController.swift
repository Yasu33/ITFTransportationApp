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
import Reachability

class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, UIPickerViewDelegate, UIPickerViewDataSource, UIApplicationDelegate {
    
    // Wifi確認
    let reachability = Reachability()!
    
    // 地図
    @IBOutlet var myMapView: MKMapView!
    
    @IBOutlet var whiteView: UIView!
    
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
    
    // バス停の位置にピンを置くための配列
    var busStopAnnotation =  [CustomAnnotation()]

    // バス停の緯度と経度
    var busStationLocations: [[Double]] = [
        [36.082332, 140.112653], // センター
        [36.085212, 140.109008], // 吾妻小
        [36.087545, 140.107476], // 春日エリア
        [36.090498, 140.105427], // メディカルセンター前
        [36.093089, 140.103861], // 大学病院
        [36.095479, 140.102852], // 追越
        [36.097552, 140.102181], // 平砂
        [36.103478, 140.101470], // 体芸
        [36.104750, 140.101211], // 大学会館
        [36.107912, 140.099867], // 第一エリア
        [36.110151, 140.098573], // 第三エリア
        [36.114039, 140.097107], // 虹の広場
        [36.118506, 140.096100], // 農林技術センター
        [36.119423, 140.099079], // 一の矢
        [36.116028, 140.102068], // 植物見本園
        [36.112966, 140.102378], // TARAセンター
        [36.111305, 140.103565], // 大学中央
        [36.109810, 140.104011], // 大学公園
        [36.108065, 140.104286], // 松美池
        [36.106376, 140.105643], // 天三
        [36.103708, 140.106702], // 合宿所
        [36.100709, 140.106090], // 天久保池
        [36.097366, 140.106070], // 天二
        [36.094633, 140.106710], // 追越宿舎東
        [36.092366, 140.105752], // メディカルセンター病院
        [36.113515, 140.100857]  // 第二エリア
    ]
    
    // バス停の名前
    var busStationNames: [String] = [
        "つくばセンター", "吾妻小学校", "筑波大学春日エリア前", "筑波メディカルセンター前",
        "筑波大学病院入口", "追越学生宿舎前", "平砂学生宿舎前", "筑波大学西", "大学会館前",
        "第一エリア前", "第三エリア前", "虹の広場", "農林技術センター", "一ノ矢学生宿舎前",
        "大学植物見本園", "TARAセンター前", "筑波大学中央", "大学公園", "松美池", "天久保三丁目",
        "合宿所", "天久保池", "天久保二丁目", "追越宿舎東", "メディカルセンター病院", "第二エリア前"
    ]
    
    // 選択されたバス
    var selectedBus: String!
    
    // pickerview
    @IBOutlet var pickerView: UIPickerView!
    
    // userDocumentID
    var userDocumentID: String!
    
    // 通信中のバスの位置のピン
    var busAnnotation: [CustomAnnotation] = []
    
    // 現在通信中のバスの位置
    var realtimeBusLocations = [[Double]]()
    
    var ridingSwitch : Bool = false
    
    // タイマー
    var checkTimer: Timer!
    
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
        let initialCoordinate = CLLocationCoordinate2DMake(36.098, 140.1033)
        let span = MKCoordinateSpan.init(latitudeDelta: 0.045, longitudeDelta: 0.034)
        let region = MKCoordinateRegion(center: initialCoordinate, span: span)
        
        // 地図の表示
        myMapView.setRegion(region, animated: true)
        
        // バス停の位置にピンを表示
        for i in 0...25 {
            busStopAnnotation.append(CustomAnnotation())
            busStopAnnotation[i].coordinate = CLLocationCoordinate2DMake(busStationLocations[i][0], busStationLocations[i][1])
            busStopAnnotation[i].title = busStationNames[i]
            busStopAnnotation[i].pinImage = "BusStop16px.png"
        }
        myMapView.addAnnotations(busStopAnnotation)
        
        // 位置情報がオンになっているか
        print(CLLocationManager.locationServicesEnabled())
        
        // バックグラウンドでの位置情報取得
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
                alertMessage(message: "位置情報サービスの利用が制限されているため利用できません。「設定」⇒「一般」⇒「機能制限」")
                
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
        db.collection("BusData").addSnapshotListener(includeMetadataChanges: true) {(snapShot, error) in
            guard let value = snapShot else {
                print("snapShot is nil")
                return
            }
            
            // バスの位置を表示
            self.pointLocations()
            
        }
        
        self.checkFireBase()
        // 10秒に一回FirebaseのDatabaseをチェックする
        checkTimer = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(self.checkFireBase), userInfo: nil, repeats: true)
        
        // アプリの終了を観察
//        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationWillTerminate(_:)), name: UIApplication.willTerminateNotification, object: nil)
        
        // WiFi情報を確認
        NotificationCenter.default.addObserver(self, selector: #selector(self.reachabilityChanged), name: .reachabilityChanged, object: reachability)
        try? reachability.startNotifier()
        
        whiteView.layer.cornerRadius = 20
        
    }
    
//    // アプリが終了した時
//    func applicationWillTerminate(_ application: UIApplication) {
//        //位置情報の更新やめる
//        if userDocumentID != nil {
//            db.collection("BusData").document(userDocumentID).delete()
//        }
//    }
    
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
                db.collection("BusData").document(userDocumentID).delete()
                userDocumentID = nil
            }
            ridingSwitch = false
        }else{
            if CLLocationManager.locationServicesEnabled() {
                button.setBackgroundImage(UIImage(named: "getoff.png"), for: .normal)

                // 位置情報更新し始める
                myLocationManager.startUpdatingLocation()
                // pickerviewで選択されたバス
                selectedBus = busRoute[pickerView.selectedRow(inComponent: 0)]
                ridingSwitch = true
            }else{
                myLocationManager.requestAlwaysAuthorization()
            }
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
            
            // 前の書き込み位置から15m進んだらFirebaseに書き込み
            if distance > 15 {
                
                // Firebase
                let data = [
                    "Bus": selectedBus!,
                    "latitude": location.coordinate.latitude,
                    "longitude": location.coordinate.longitude,
                    "createdAt": FieldValue.serverTimestamp()
                    ] as [String : Any]
                
                if userDocumentID == nil {
                    ref = db.collection("BusData").addDocument(data: data){ err in
                        if let err = err {
                            print("Error adding document: \(err)")
                        } else {
//                            print("Document added with ID: \(self.ref!.documentID)")
                        }
                    }
                    userDocumentID = self.ref!.documentID
                }else{
                    db.collection("BusData").document(userDocumentID).updateData(data)
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
            // CustomAnnotationに設定された画像に合わせてピンの画像をセット
            if let newAnnotation = annotation as? CustomAnnotation {
                let pinView = MKAnnotationView()
                pinView.annotation = annotation
                pinView.image = UIImage(named: newAnnotation.pinImage)
                pinView.canShowCallout = true
                return pinView
            }else{
                print("annotation error")
                return nil
            }
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
        
        self.db.collection("BusData").getDocuments () { (querySnapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            } else {
                // realtimeBusLocaionsの中身を全消去
                self.realtimeBusLocations.removeAll()
                // 一度map上のピンを全消去
                self.myMapView.removeAnnotations(self.busAnnotation)
                // annotationの中身を全消去
                self.busAnnotation.removeAll()
                // 現在データベースに送られている位置情報を配列に入れる
                for document in querySnapshot!.documents {
//                    print("\(document.documentID) => \(document.data())")
                    self.realtimeBusLocations.append([document.data()["latitude"] as! Double, document.data()["longitude"] as! Double])
                    self.busAnnotation.append(CustomAnnotation())
                }
                
//                print(self.realtimeBusLocations)
                if self.realtimeBusLocations.count > 0 {
                    for i in 0...(self.realtimeBusLocations.count - 1) {
                        //database中に記録されている位置にピンを立てる
                        self.busAnnotation[i].pinImage = "\(describing: querySnapshot!.documents[i].data()["Bus"]!).png"
                        self.busAnnotation[i].coordinate = CLLocationCoordinate2DMake(self.realtimeBusLocations[i][0], self.realtimeBusLocations[i][1])
                    }
                    self.myMapView.addAnnotations(self.busAnnotation)
                }
                
            }
        }
    }
    
    @objc func checkFireBase() {
        self.db.collection("BusData").getDocuments () { (querySnapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            } else {
                let now = NSDate()
//                print(now)
                for document in querySnapshot!.documents {
                    let docID = document.documentID
                    if document.data()["createdAt"] is NSNull {
                        print("nullでした")
                    }else{
                        let documentTimestamp = document.data()["createdAt"] as! Timestamp
//                    print(documentTimestamp.dateValue())
                        let span = now.timeIntervalSince(documentTimestamp.dateValue() as Date)
                        if span > 60 {
                            self.db.collection("BusData").document(docID).delete()
                        }
                    }
                    
                }
            }
        }
    }
    
    @objc func reachabilityChanged() {
        button.setBackgroundImage(UIImage(named: "ride.png"), for: .normal)
        //位置情報の更新やめる
        if userDocumentID != nil {
            myLocationManager.stopUpdatingLocation()
            db.collection("BusData").document(userDocumentID).delete()
            userDocumentID = nil
        }
        ridingSwitch = false
    }
    
}

