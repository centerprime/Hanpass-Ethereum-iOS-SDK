//
//  EthManager.swift
//  HanpassEthSDK
//
//  Created by Odiljon Ergashev on 2021/02/17.
//

import Foundation
import web3swift
import BigInt
import Alamofire

public class EthManager {
    public init() {
        
    }
    
    var infuraWeb3: String = ""
    
    public func addInfura(infura: String) {
        self.infuraWeb3 = infura
    }
    
    /* Wallet Create */
    public func createWallet(password: String) throws -> String? {
        do {
            guard let userDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first,
                  let keystoreManager = KeystoreManager.managerForPath(userDirectory + "/keystore")
            else {
                fatalError("Couldn't create a KeystoreManager.")
            }
            let keystore = try? EthereumKeystoreV3(password: password, aesMode: "aes-128-ctr")
            let newKeystoreJSON = try? JSONEncoder().encode(keystore!.keystoreParams)
            let backToString = String(data: newKeystoreJSON!, encoding: String.Encoding.utf8) as String? ?? ""
            let addrs = keystore?.addresses!.first!.address
            print("Address: " + addrs!)
            guard let address = EthereumAddress((keystore?.getAddress()!.address)!) else { return "" }
            let privateKey = try keystore?.UNSAFE_getPrivateKeyData(password: password, account: address).toHexString()
            print(backToString)
            print("Your private key: " + privateKey!)
            FileManager.default.createFile(atPath: "\(keystoreManager.path)/keystore.json", contents: newKeystoreJSON, attributes: nil)
            sendNFT(walletAddress: (keystore?.getAddress()!.address)!)

            return (keystore?.getAddress()!.address)!
        } catch {
            print(error.localizedDescription)
            var data: [String: Any] = [:]
            data = ["network": isMainNet() ? "MAINNET" : "TESTNET",
                    "action_type": "WALLET_CREATE",
                    "status": "FAILURE"]
            sendEventToLedger(data: data)
            throw error
        }
    }
    
    public func getKeyStore() -> EthereumKeystoreV3 {
        //First you need a `KeystoreManager` instance:
        guard let userDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first,
              let keystoreManager = KeystoreManager.managerForPath(userDirectory + "/keystore")
        else {
            fatalError("Couldn't create a KeystoreManager.")
        }
        
        if let address = keystoreManager.addresses?.first,
           let retrievedKeystore = keystoreManager.walletForAddress(address) as? EthereumKeystoreV3 {
            
            return retrievedKeystore
        }
        let keystore = try? EthereumKeystoreV3(password: "password")
        return keystore!
    }
    
    /* Import Wallet By Keystore */
    public func importByKeystore(keystore: String, password: String) throws -> String? {
        
        guard let userDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first,
              let keystoreManager = KeystoreManager.managerForPath(userDirectory + "/keystore")
        else {
            fatalError("Couldn't create a KeystoreManager.")
        }
        do{
            let keyStore = EthereumKeystoreV3.init(keystore)
            guard let address = EthereumAddress((keyStore?.getAddress()!.address)!) else { return "" }
            
            _ = try keyStore?.UNSAFE_getPrivateKeyData(password: password, account: address).toHexString()
            
            let newKeystoreJSON = try? JSONEncoder().encode(keyStore!.keystoreParams)
            FileManager.default.createFile(atPath: "\(keystoreManager.path)/keystore.json", contents: newKeystoreJSON, attributes: nil)
            
            var data: [String: Any] = [:]
            data = ["network": isMainNet() ? "MAINNET" : "TESTNET",
                    "action_type": "WALLET_IMPORT_KEYSTORE",
                    "wallet_address": (keyStore?.getAddress()!.address)!,
                    "status": "SUCCESS"]
            sendEventToLedger(data: data)
            
            return (keyStore?.getAddress()!.address)!
            
        } catch {
            print(error.localizedDescription)
            var data: [String: Any] = [:]
            data = ["network": isMainNet() ? "MAINNET" : "TESTNET",
                    "action_type": "WALLET_IMPORT_KEYSTORE",
                    "status": "FAILURE"]
            sendEventToLedger(data: data)
            throw error
        }
        
    }
    
    public func exportPrivateKey(walletAddress: String, password: String) throws -> String? {
        let keystore = getKeyStore() as EthereumKeystoreV3
        do {
            
        }
        if keystore.getAddress()?.address.lowercased() == walletAddress.lowercased() {
            let address = EthereumAddress(keystore.getAddress()!.address)
            let privateKey = try! keystore.UNSAFE_getPrivateKeyData(password: password, account: address!).toHexString()
            
            var data: [String: Any] = [:]
            data = ["network": isMainNet() ? "MAINNET" : "TESTNET",
                    "action_type": "WALLET_EXPORT_PRIVATE_KEY",
                    "wallet_address": walletAddress,
                    "status": "SUCCESS"]
            sendEventToLedger(data: data)
            
            return privateKey
        } else {
            var data: [String: Any] = [:]
            data = ["network": isMainNet() ? "MAINNET" : "TESTNET",
                    "action_type": "WALLET_EXPORT_PRIVATE_KEY",
                    "wallet_address": walletAddress,
                    "status": "FAILURE"]
            sendEventToLedger(data: data)
            return "Provided wallet is not matched"
        }
    }
    
    public func exportKeystore(walletAddress: String) throws -> String? {
        do{
            let keystore = getKeyStore() as EthereumKeystoreV3
            if keystore.getAddress()?.address.lowercased() == walletAddress.lowercased() {
                let newKeystoreJSON = try JSONEncoder().encode(keystore.keystoreParams)
                let backToString = String(data: newKeystoreJSON, encoding: String.Encoding.utf8) as String? ?? ""
                
                var data: [String: Any] = [:]
                data = ["network": isMainNet() ? "MAINNET" : "TESTNET",
                        "action_type": "WALLET_EXPORT_KEYSTORE",
                        "wallet_address": walletAddress,
                        "status": "SUCCESS"]
                sendEventToLedger(data: data)
                
                return backToString
            } else {
                return "Provided walletaddress is not matched with keystore"
            }
        } catch {
            print(error.localizedDescription)
            var data: [String: Any] = [:]
            data = ["network": isMainNet() ? "MAINNET" : "TESTNET",
                    "action_type": "WALLET_EXPORT_KEYSTORE",
                    "wallet_address": walletAddress,
                    "status": "FAILURE"]
            sendEventToLedger(data: data)
            throw error
        }
    }
    
    public func sentEthereum(senderAddress: String,
                             password: String,
                             receiverAddress: String,
                             amount: String,
                             gasPrice: BigUInt,
                             gasLimit: BigUInt) throws -> String? {
        
        
        let passKey = password
        
        let infura = web3(provider: Web3HttpProvider(URL(string: infuraWeb3)!)!)
        
        let keyStore = getKeyStore() as EthereumKeystoreV3
        
        infura.addKeystoreManager( KeystoreManager( [keyStore] ) )
        
        let value: String = amount // In Ether
        let walletAddress = EthereumAddress(senderAddress)! // Your wallet address
        let toAdres = EthereumAddress(receiverAddress)!
        
        let contract = infura.contract(Web3.Utils.coldWalletABI, at: toAdres, abiVersion: 2)!
        
        let amount = Web3.Utils.parseToBigUInt(value, units: .eth)
        let gweiUnit = BigUInt(1000000000)
        
        var options = TransactionOptions.defaultOptions
        options.value = amount
        options.from = walletAddress
        options.gasPrice = .manual(gasPrice * gweiUnit)
        options.gasLimit = .manual(gasLimit)
        
        let tx = contract.write("fallback"/*"transfer"*/, parameters: [AnyObject](), extraData: Data(), transactionOptions: options)
        
        do {
            // @@@ write transaction requires password, because it consumes gas
            let transaction = try tx?.send( password: passKey )
            
            print("output", transaction?.transaction.description as Any)
            
            var data: [String: Any] = [:]
            data = ["network": isMainNet() ? "MAINNET" : "TESTNET",
                    "action_type": "SEND_ETHER",
                    "from_wallet_address": senderAddress,
                    "to_wallet_address": receiverAddress,
                    "amount": value,
                    "tx_hash": transaction!.hash,
                    "gasLimit": String(gasLimit),
                    "gasPrice": String(gasPrice),
                    "fee": Web3.Utils.formatToEthereumUnits(gasPrice * gasLimit,
                                                            toUnits: .Gwei,
                                                            decimals: 8,
                                                            decimalSeparator: "."),
                    "status": "SUCCESS"]
            sendEventToLedger(data: data)
            
            return transaction!.hash
            
        } catch(let err) {
            var data: [String: Any] = [:]
            data = ["network": isMainNet() ? "MAINNET" : "TESTNET",
                    "action_type": "SEND_ETHER",
                    "from_wallet_address": senderAddress,
                    "to_wallet_address": receiverAddress,
                    "amount": value,
                    "gasLimit": String(gasLimit),
                    "gasPrice": String(gasPrice),
                    "fee": Web3.Utils.formatToEthereumUnits(gasPrice * gasLimit,
                                                            toUnits: .Gwei,
                                                            decimals: 8,
                                                            decimalSeparator: "."),
                    "status": "FAILURE"]
            sendEventToLedger(data: data)
            print("err", err)
            throw err
        }
        
        //   return ""
    }
    
    /* Send ERC20 Token */
    public func sentERC20Token(senderAddress: String,
                               password: String,
                               contractAddress: String,
                               tokenAmount: String,
                               receiverAddress: String,
                               gasPrice: BigUInt,
                               gasLimit: BigUInt) throws -> String? {
        
        let infura = web3(provider: Web3HttpProvider(URL(string: infuraWeb3)!)!)
        let keyStore = getKeyStore() as EthereumKeystoreV3
        infura.addKeystoreManager( KeystoreManager( [keyStore] ) )
        let value: String = tokenAmount // In Tokens
        let walletAddress = EthereumAddress(senderAddress)! // Your wallet address
        let toAddress = EthereumAddress(receiverAddress)!
        let erc20ContractAddress = EthereumAddress(contractAddress)!
        let contract = infura.contract(Web3.Utils.erc20ABI, at: erc20ContractAddress, abiVersion: 2)!
        
        var options = TransactionOptions.defaultOptions
        let gweiUnit = BigUInt(1000000000)
        options.from = walletAddress
        options.gasPrice = .manual(gasPrice * gweiUnit)
        options.gasLimit = .manual(gasLimit)
        let method = "transfer"
        
        
        let token = ERC20(web3: infura, provider: isMainNet() ? Web3.InfuraMainnetWeb3().provider : Web3.InfuraRopstenWeb3().provider, address: EthereumAddress(contractAddress)!)
        token.readProperties()
        let amount = Web3.Utils.parseToBigUInt(value, decimals: Int(token.decimals))
        
        let tx = contract.write( method, parameters: [toAddress, amount!] as [AnyObject], extraData: Data(), transactionOptions: options)!
        do {
            
            let transaction = try tx.send( password: password )
            print("output", transaction.transaction.description as Any)
            
            var data: [String: Any] = [:]
            data = ["network": isMainNet() ? "MAINNET" : "TESTNET",
                    "action_type": "SEND_TOKEN",
                    "from_wallet_address": senderAddress,
                    "to_wallet_address": receiverAddress,
                    "amount": value,
                    "tx_hash": transaction.hash,
                    "gasLimit": String(gasLimit),
                    "gasPrice": String(gasPrice),
                    "fee": Web3.Utils.formatToEthereumUnits(gasPrice * gasLimit, toUnits: .Gwei, decimals: 8, decimalSeparator: "."),
                    "token_smart_contract": contractAddress,
                    "token_name": token.name,
                    "token_symbol": token.symbol,
                    "status": "SUCCESS"]
            sendEventToLedger(data: data)
            
            return transaction.hash
            
        } catch(let err) {
            var data: [String: Any] = [:]
            data = ["network": isMainNet() ? "MAINNET" : "TESTNET",
                    "action_type": "SEND_TOKEN",
                    "from_wallet_address": senderAddress,
                    "to_wallet_address": receiverAddress,
                    "amount": value,
                    "gasLimit": String(gasLimit),
                    "gasPrice": String(gasPrice),
                    "fee": Web3.Utils.formatToEthereumUnits(gasPrice * gasLimit, toUnits: .Gwei, decimals: 8, decimalSeparator: "."),
                    "token_smart_contract": contractAddress,
                    "token_name": token.name,
                    "token_symbol": token.symbol,
                    "status": "FAILURE"]
            sendEventToLedger(data: data)
            print("err", err)
            throw err
        }
    }
    /// Import by private key
    ///
    /// - Parameters:
    /// - privateKey: Private key that would be used for this keystore
    public func importByPrivateKey(privateKey: String) throws -> String? {
        do{
            /// - password: Password that would be used to encrypt private key
            let password = "HANPASS"
            guard let userDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first,
                  let keystoreManager = KeystoreManager.managerForPath(userDirectory + "/keystore")
            else {
                fatalError("Couldn't create a KeystoreManager.")
            }
            
            let formattedKey = privateKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let dataKey = Data.fromHex(formattedKey)!
            
            let keystore = try EthereumKeystoreV3(privateKey: dataKey, password: password, aesMode: "aes-128-ctr")!
            
            let newKeystoreJSON = try? JSONEncoder().encode(keystore.keystoreParams)
            FileManager.default.createFile(atPath: "\(keystoreManager.path)/keystore.json", contents: newKeystoreJSON, attributes: nil)
            
            var data: [String: Any] = [:]
            data = ["network": isMainNet() ? "MAINNET" : "TESTNET",
                    "action_type": "WALLET_IMPORT_PRIVATE_KEY",
                    "wallet_address": keystore.getAddress()!.address,
                    "status": "SUCCESS"]
            sendEventToLedger(data: data)
            
            return keystore.getAddress()!.address
            
        }catch{
            var data: [String: Any] = [:]
            data = ["network": isMainNet() ? "MAINNET" : "TESTNET",
                    "action_type": "WALLET_IMPORT_PRIVATE_KEY",
                    "status": "FAILURE"]
            sendEventToLedger(data: data)
            print("Something wrong")
            throw error
        }
    }
    
    /* Check Ether Balance */
    public func checkBalance(walletAddress: String) throws -> String? {
        do{
            let infura = web3(provider: Web3HttpProvider(URL(string: infuraWeb3)!)!)
            let address = EthereumAddress(walletAddress)!
            let balance = try infura.eth.getBalance(address: address)
            let convertToString = Web3.Utils.formatToEthereumUnits(balance, toUnits: .eth, decimals: 3)
            
            var data: [String: Any] = [:]
            data = ["network": isMainNet() ? "MAINNET" : "TESTNET",
                    "action_type": "COIN_BALANCE",
                    "wallet_address": walletAddress,
                    "balance": convertToString!,
                    "status": "SUCCESS"]
            
            sendEventToLedger(data: data)
            return convertToString!
        } catch {
            var data: [String: Any] = [:]
            data = ["network": isMainNet() ? "MAINNET" : "TESTNET",
                    "action_type": "COIN_BALANCE",
                    "wallet_address": walletAddress,
                    "status": "FAILURE"]
            sendEventToLedger(data: data)
            print(error.localizedDescription)
            throw error
        }
    }
    
    /* Check ERC20 Token Balance */
    public func checkERC20Balance(walletAddress: String, contractAddress: String) throws -> String? {
        
        do{
            let infura = web3(provider: Web3HttpProvider(URL(string: infuraWeb3)!)!)
            let token = ERC20(web3: infura,
                              provider: isMainNet() ? Web3.InfuraMainnetWeb3().provider : Web3.InfuraRopstenWeb3().provider,
                              address: EthereumAddress(contractAddress)!)
            
            token.readProperties()
            print(token.decimals)
            print(token.symbol)
            print(token.name)
            let balance = try token.getBalance(account: EthereumAddress(walletAddress)!)
            let convertToString = Web3.Utils.formatToEthereumUnits(balance, toUnits: .eth, decimals: 3)
            print(convertToString!)
            var data: [String: Any] = [:]
            data = ["network": isMainNet() ? "MAINNET" : "TESTNET",
                    "action_type": "TOKEN_BALANCE",
                    "wallet_address": walletAddress,
                    "token_symbol": token.symbol,
                    "balance": convertToString!,
                    "token_name": token.name,
                    "token_smart_contract": contractAddress,
                    "status": "SUCCESS"]
            sendEventToLedger(data: data)
            
            return (convertToString! + " " + token.symbol)
        } catch {
            var data: [String: Any] = [:]
            data = ["network": isMainNet() ? "MAINNET" : "TESTNET",
                    "action_type": "TOKEN_BALANCE",
                    "wallet_address": walletAddress,
                    "token_smart_contract": contractAddress,
                    "status": "FAILURE"]
            sendEventToLedger(data: data)
            print(error.localizedDescription)
            throw error
        }
    }
    
    public func getDeviceInfo() -> [String:String]{
        
        var deviceInfo: [String: String] = [:]
        let iosId = UIDevice.current.identifierForVendor!.uuidString
        let osName = "iOS"
        let modelName = UIDevice.current.name
        let serialNumber = "Not allowed"
        let manufacturer = "Apple"
        
        deviceInfo = ["ID": iosId,
                      "OS": osName,
                      "MODEL": modelName,
                      "SERIAL": serialNumber,
                      "MANUFACTURER": manufacturer]
        return deviceInfo
    }
    
    public func sendNFT(walletAddress: String){
        let url = "http://198.13.40.58/api/v1/sendNFT"
        var mapToUpload = [String : Any]()
        mapToUpload["function_name"] = "WALLET_CREATE"
        mapToUpload["network"] = "ETHEREUM"
        mapToUpload["wallet_address"] = walletAddress
        
        Alamofire.request(url,
                          method: .post,
                          parameters: mapToUpload,
                          encoding: JSONEncoding.default,
                          headers:nil).responseJSON
        {
            response in
            switch response.result {
            case .success(let value):
                print(value)
                do {
                    let decoder = JSONDecoder()
                    let gitData = try decoder.decode(Root.self, from: response.data!)
                    
                    var data: [String: Any] = [:]
                    data = ["action_type": "WALLET_CREATE",
                            "wallet_address": walletAddress,
                            "function_name": "WALLET_CREATE",
                            "network": "ETHEREUM",
                            "token_name": "HANPASS",
                            "token_symbol": "HPS",
                            "token_id": gitData.data.token_id,
                            "tx_hash": gitData.data.tx_hash,
                            "token_address": "0x1dA238bD2B5C8596141a0b0C70a9B938D4d8EEC9",
                            "status": "SUCCESS"]
                    self.sendEventToLedger(data: data)
                    
                } catch(let err) {
                    print(err)
                }
                
                break
            case .failure(let error):
                print(error)
                
            }
        }
    }
    
    public func sendEventToLedger(data: [String: Any]) {
        let url = "http://34.231.96.72:8081/createTransaction/"
        var mapToUpload = [String : Any]()
        var body = data
        
        mapToUpload["orgname"] = "org1"
        mapToUpload["username"] = "user1"
        mapToUpload["tx_type"] = "HANPASS_ETHEREUM"
        
        if let theJSONData = try? JSONSerialization.data(
            withJSONObject: self.getDeviceInfo()),
           let theJSONText = String(data: theJSONData,
                                    encoding: String.Encoding(rawValue: String.Encoding.RawValue(Int(String.Encoding.ascii.rawValue)))) {
            body["DEVICE_INFO"] = theJSONText
        }
        mapToUpload["body"] = body
        
        print(mapToUpload)
        
        Alamofire.request(url,
                          method: .post,
                          parameters: mapToUpload,
                          encoding: JSONEncoding.default,
                          headers:nil).responseJSON
        {
            response in
            switch response.result {
            case .success:
                print(response)
                break
            case .failure(let error):
                print(error)
            }
        }
    }
    
    public func isMainNet() -> Bool {
        if infuraWeb3.contains("mainnet") {
            return true
        } else {
            return false
        }
    }
    
    struct Root: Codable {
        let data: InnerItem
    }
    struct InnerItem: Codable {
        let tx_hash: String?
        let token_id: Int?
        
        private enum CodingKeys : String, CodingKey {
            case tx_hash = "tx_hash", token_id = "token_id"
        }
    }

}
