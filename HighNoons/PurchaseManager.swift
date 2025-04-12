import StoreKit
import Foundation

final class PurchaseManager {
    // MARK: - Types
    enum PurchaseError: Error {
        case productNotFound
        case purchaseFailed(Error?)
        case purchaseCancelled
        case receiptValidationFailed
        case notAuthorized
        case networkError
    }
    
    enum ProductType: String {
        // Currency
        case coins1000 = "com.highnoons.coins.1000"
        case coins2500 = "com.highnoons.coins.2500"
        case coins5000 = "com.highnoons.coins.5000"
        
        // Characters
        case sheriffCharacter = "com.highnoons.character.sheriff"
        case outlawCharacter = "com.highnoons.character.outlaw"
        case marshalCharacter = "com.highnoons.character.marshal"
        
        // Power-ups
        case slowMotion = "com.highnoons.powerup.slowmo"
        case quickDraw = "com.highnoons.powerup.quickdraw"
        case extraLife = "com.highnoons.powerup.extralife"
        
        // Premium Features
        case removeAds = "com.highnoons.premium.noads"
        case allCharacters = "com.highnoons.premium.allcharacters"
        case vipPass = "com.highnoons.premium.vip"
        
        var isConsumable: Bool {
            switch self {
            case .coins1000, .coins2500, .coins5000,
                 .slowMotion, .quickDraw, .extraLife:
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - Properties
    static let shared = PurchaseManager()
    private let playerStats = PlayerStats.shared
    
    private var products: [ProductType: SKProduct] = [:]
    private var purchaseHandlers: [String: (Result<Bool, PurchaseError>) -> Void] = [:]
    
    // Receipt validation
    private let receiptValidationURL = URL(string: "https://api.highnoons.com/validate-receipt")!
    private let serverSecret = "YOUR_SERVER_SECRET" // Replace with actual secret
    
    // MARK: - Initialization
    private init() {
        setupStoreKit()
    }
    
    private func setupStoreKit() {
        SKPaymentQueue.default().add(self)
        loadProducts()
    }
    
    // MARK: - Product Management
    private func loadProducts() {
        let productIdentifiers = Set(ProductType.allCases.map { $0.rawValue })
        let request = SKProductsRequest(productIdentifiers: productIdentifiers)
        request.delegate = self
        request.start()
    }
    
    func getProduct(_ type: ProductType) -> SKProduct? {
        return products[type]
    }
    
    func getFormattedPrice(for type: ProductType) -> String? {
        guard let product = products[type] else { return nil }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        return formatter.string(from: product.price)
    }
    
    // MARK: - Purchase Flow
    func purchase(_ type: ProductType, completion: @escaping (Result<Bool, PurchaseError>) -> Void) {
        guard SKPaymentQueue.canMakePayments() else {
            completion(.failure(.notAuthorized))
            return
        }
        
        guard let product = products[type] else {
            completion(.failure(.productNotFound))
            return
        }
        
        let payment = SKPayment(product: product)
        purchaseHandlers[product.productIdentifier] = completion
        SKPaymentQueue.default().add(payment)
    }
    
    func restorePurchases(completion: @escaping (Result<Bool, PurchaseError>) -> Void) {
        guard SKPaymentQueue.canMakePayments() else {
            completion(.failure(.notAuthorized))
            return
        }
        
        purchaseHandlers["restore"] = completion
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    // MARK: - Purchase Processing
    private func processPurchase(_ transaction: SKPaymentTransaction) {
        guard let productId = transaction.payment.productIdentifier.components(separatedBy: ".").last,
              let type = ProductType(rawValue: transaction.payment.productIdentifier) else {
            finishTransaction(transaction, withResult: .failure(.productNotFound))
            return
        }
        
        // Validate receipt
        validateReceipt { [weak self] result in
            switch result {
            case .success:
                self?.grantPurchase(type)
                self?.finishTransaction(transaction, withResult: .success(true))
            case .failure(let error):
                self?.finishTransaction(transaction, withResult: .failure(error))
            }
        }
    }
    
    private func grantPurchase(_ type: ProductType) {
        switch type {
        case .coins1000:
            playerStats.addCoins(1000)
        case .coins2500:
            playerStats.addCoins(2500)
        case .coins5000:
            playerStats.addCoins(5000)
        case .sheriffCharacter, .outlawCharacter, .marshalCharacter:
            playerStats.unlockCharacter(type.rawValue)
        case .slowMotion, .quickDraw, .extraLife:
            playerStats.addPowerup(type.rawValue)
        case .removeAds:
            playerStats.setPremiumStatus(true)
            NotificationCenter.default.post(name: .adsRemoved, object: nil)
        case .allCharacters:
            unlockAllCharacters()
        case .vipPass:
            playerStats.setVIPStatus(true)
        }
    }
    
    private func unlockAllCharacters() {
        [ProductType.sheriffCharacter,
         ProductType.outlawCharacter,
         ProductType.marshalCharacter].forEach {
            playerStats.unlockCharacter($0.rawValue)
        }
    }
    
    // MARK: - Receipt Validation
    private func validateReceipt(completion: @escaping (Result<Bool, PurchaseError>) -> Void) {
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              let receiptData = try? Data(contentsOf: receiptURL) else {
            completion(.failure(.receiptValidationFailed))
            return
        }
        
        let receiptString = receiptData.base64EncodedString()
        
        var request = URLRequest(url: receiptValidationURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "receipt-data": receiptString,
            "password": serverSecret
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? Int,
                  status == 0 else {
                completion(.failure(.receiptValidationFailed))
                return
            }
            
            completion(.success(true))
        }.resume()
    }
    
    // MARK: - Transaction Handling
    private func finishTransaction(_ transaction: SKPaymentTransaction, withResult result: Result<Bool, PurchaseError>) {
        SKPaymentQueue.default().finishTransaction(transaction)
        
        if let handler = purchaseHandlers.removeValue(forKey: transaction.payment.productIdentifier) {
            DispatchQueue.main.async {
                handler(result)
            }
        }
    }
}

// MARK: - SKProductsRequestDelegate
extension PurchaseManager: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        for product in response.products {
            if let type = ProductType(rawValue: product.productIdentifier) {
                products[type] = product
            }
        }
        
        if !response.invalidProductIdentifiers.isEmpty {
            print("Invalid product identifiers: \(response.invalidProductIdentifiers)")
        }
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        print("Product request failed: \(error.localizedDescription)")
    }
}

// MARK: - SKPaymentTransactionObserver
extension PurchaseManager: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                processPurchase(transaction)
            case .failed:
                let error: PurchaseError = transaction.error?.localizedDescription.contains("cancelled") == true
                    ? .purchaseCancelled
                    : .purchaseFailed(transaction.error)
                finishTransaction(transaction, withResult: .failure(error))
            case .restored:
                processPurchase(transaction)
            case .deferred, .purchasing:
                break
            @unknown default:
                break
            }
        }
    }
    
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        if let handler = purchaseHandlers.removeValue(forKey: "restore") {
            DispatchQueue.main.async {
                handler(.success(true))
            }
        }
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        if let handler = purchaseHandlers.removeValue(forKey: "restore") {
            DispatchQueue.main.async {
                handler(.failure(.purchaseFailed(error)))
            }
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let adsRemoved = Notification.Name("adsRemoved")
}

// MARK: - ProductType Extension
extension PurchaseManager.ProductType: CaseIterable {}
