//
//  GetWundergroundConditions.swift
//  CompassionAppServices
//
//  Created by Thomas Mallow (GMC-GSS-IT-CONTRACTOR) on 07/12/17.
//  Copyright © 2016 Compassion International. All rights reserved.
//

import Foundation

/// the name of the key required for Wunderground Calls
public let WundergroundAPIKey = "WundergroundAPIKey"

public protocol GetWundergroundConditionsDelegate:class {
    func getWundergroundConditionsComplete(_ sender:GetWundergroundConditions, tempC:Float, tempF:Float, weather:String, icon:String, local_tz_short: String, local_tz_offset: String)
    func getWundergroundConditionsFailed(_ sender:GetWundergroundConditions,response:HTTPURLResponse?)
}

/// Encapsulates a call to the Wunderground Conditions API
/// Uses the "WundergroundAPIKey" Key, which must be preloaded into the ConnectionKeyManager prior to initialization of this class
public class GetWundergroundConditions: NSObject, ConnectionManagerDelegate {
    
    // MARK: - Common properties
    
    public var verbosity: VerbosityLevel = .off
    
    internal var connectionManager = ConnectionManager()
    fileprivate unowned var delegate:GetWundergroundConditionsDelegate
    
    /// The response received (if any) from the server
    fileprivate(set) public var response:HTTPURLResponse?

    // MARK: - Properties for this implementation
    fileprivate(set) public var latitude:Float
    fileprivate(set) public var longitude:Float
    
    
    // MARK: - Failable Initializer
    public init?(latitude:Float,
                 longitude:Float,
                 delegate:GetWundergroundConditionsDelegate,
                 apiKey:String=WundergroundAPIKey,
                 verbosity: VerbosityLevel = .off) {
        
        self.delegate = delegate
        self.latitude = latitude
        self.longitude = longitude
        self.verbosity = verbosity
        
        super.init()
        
        if ConnectionKeyManager.shared.keyAvailable(name: apiKey) == nil {
            return nil // keys are not available.  fail the initialization
        }
        
        var headers = [String:String]()
        headers["Accept"] = "application/json"
        
        connectionManager.cmdelegate = self
        connectionManager.verbosity = verbosity
        
        // get the queue to run the key call in
        if let queue = ConnectionKeyManager.shared.queue(name: apiKey) {
            // pull the queue and run it
            queue.async {
                // pull the key
                if let key = ConnectionKeyManager.shared.key(name: apiKey),
                    let address = "https://api.wunderground.com/api/\(key)/conditions/q/\(latitude),\(longitude).json".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
                    // run the connection
                    if !self.connectionManager.getMessage(fromServer: address, headers: nil, beginImmediately: true, sessionID: nil) {
                        // something broke when we tried to start the call, let the delegate know
                        delegate.getWundergroundConditionsFailed(self,response: self.response)
                    }
                } else {
                    delegate.getWundergroundConditionsFailed(self,response: self.response)
                }
            }
        } else {
            // should never get to this point unless something breaks in the ConnectionKeyManager between the check for key validity and here.
            return nil
        }
    }
    
    
    // MARK: - Test Stubs
    internal init(delegate:GetWundergroundConditionsDelegate) {
        self.latitude = 0.0
        self.longitude = 0.0
        self.delegate = delegate
        super.init()
        self.connectionManager.cmdelegate = self
    }

    
    public func operationComplete(connectionManager: ConnectionManager) {
        if let data = connectionManager.receivedData {
            do {
                let dataJSON = try JSONSerialization.jsonObject(with: data as Data, options: JSONSerialization.ReadingOptions.allowFragments)
                if let dataDict = dataJSON as? NSDictionary {
                    if let current_observation = dataDict.object(forKey: "current_observation") as? NSDictionary,
                        let temp_f = current_observation.object(forKey: "temp_f") as? Float,
                        let temp_c = current_observation.object(forKey: "temp_c") as? Float,
                        let weather = current_observation.object(forKey: "weather") as? String,
                        let icon = current_observation.object(forKey: "icon") as? String,
                        let local_tz_short = current_observation.object(forKey: "local_tz_short") as? String,
                        let local_tz_offset = current_observation.object(forKey: "local_tz_offset") as? String {
                        delegate.getWundergroundConditionsComplete(self, tempC: temp_c, tempF: temp_f, weather: weather, icon: icon, local_tz_short: local_tz_short, local_tz_offset: local_tz_offset)
                    } else {
                        delegate.getWundergroundConditionsFailed(self, response: response)
                    }
                } else {
                    delegate.getWundergroundConditionsFailed(self, response: response)
                }
            } catch {
                print(error)
                delegate.getWundergroundConditionsFailed(self, response: response)
            }
        } else {
            delegate.getWundergroundConditionsFailed(self, response: response)
        }
    }
    public func operationFailed(connectionManager: ConnectionManager) {
        delegate.getWundergroundConditionsFailed(self, response: response)
    }
    public func uploadInProgress(connectionManager: ConnectionManager) {
        // NOOP
    }
    public func downloadInProgress(connectionManager: ConnectionManager) {
        // NOOP
    }
    public func responseReceived(connectionManager: ConnectionManager, response: HTTPURLResponse) {
        self.response = response
    }
}
