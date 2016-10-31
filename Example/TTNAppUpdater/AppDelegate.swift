//
//  AppDelegate.swift
//  TTNAppUpdater
//
//  Created by Ajay Sharma on 10/19/2016.
//  Copyright (c) 2016 Ajay Sharma. All rights reserved.
//

import UIKit
import TTNAppUpdater
import CoreTelephony


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        setupAppUpdater()
        
        return true
    }
    
    func setupAppUpdater() {
        
        let appUpdater = AppUpdater.sharedInstance
        
        // Optional
        appUpdater.delegate = self
        
        // Optional
        appUpdater.debugEnabled = true
        
        // Optional - Defaults to .Option
        appUpdater.alertType = .option // or .Force, .Skip, .None
        
        appUpdater.forceLanguageLocalization = .English
        
        // Alert Appearance Color
        appUpdater.alertControllerTintColor = UIColor.red
        
        // Setup the Network Info and create a CTCarrier object
        let networkInfo = CTTelephonyNetworkInfo()
        let carrier = networkInfo.subscriberCellularProvider
        
        // Get carrier name
        let carrierName = carrier?.carrierName
        
        // Required - Get Headers Info
        let headerDictionary = [
            UIDevice.current.systemName : "platform",
            UIDevice.current.systemVersion : "osVersion",
            "192.168.1.1" : "ipAddress",
            UIDevice.current.localizedModel : "locale",
            "1.1" : "appVersion",
            "WiFi" : "networkType",
            UIDevice.current.name : "deviceName",
            (carrierName ?? "").isEmpty ? "No Sim Detected" : carrierName! : "carrier"]
        appUpdater.headerDictionary = headerDictionary
        
        // Required
        appUpdater.checkVersion(.immediately)
    }
    
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
}

extension AppDelegate: AppUpdaterDelegate
{
    func appUpdaterDidShowUpdateDialog(_ alertType: AppUpdaterAlertType) {
        print(#function, alertType)
    }
    
    func appUpdaterUserDidCancel() {
        print(#function)
    }
    
    func appUpdaterUserDidSkipVersion() {
        print(#function)
    }
    
    func appUpdaterUserDidLaunchAppStore() {
        print(#function)
    }
    
    func appUpdaterDidFailVersionCheck(_ error: NSError) {
        print(#function, error)
    }
    
    /**
     This delegate method is only hit when alertType is initialized to .None
     */
    func appUpdaterDidDetectNewVersionWithoutAlert(_ message: String) {
        print(#function, "\(message)")
    }
    
    func appUpdaterDidCompleteVersionCheckWithConfigData(_ message: NSDictionary) {
        print(#function, "\(message)")
    }
    
    
}


