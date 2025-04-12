import Foundation

final class MarketplaceManager {
    // MARK: - Properties
    static let shared = MarketplaceManager()
    
    private let networkManager = NetworkManager.shared
    private let analytics = AnalyticsManager.shared
    private let playerStats = PlayerStats.shared
    
    private var activeListings: [Listing] = []
    private var userListings: [Listing] = []
    private var watchlist: Set<String> = []
    private var marketStats: MarketStats?
    private var refreshTimer: Timer?
    
    // MARK: - Types
    struct Listing: Codable {
        let id: String
        let sellerId: String
        let item: MarketItem
        let price: Price
        let quantity: Int
        let expiryDate: Date
        let status: Status
        let tags: [String]
        let timestamp: Date
        
        struct MarketItem: Codable {
            let id: String
            let type: ItemType
            let name: String
            let description: String
            let rarity: Rarity
            let tradeable: Bool
            let metadata: [String: String]
            
            enum ItemType: String, Codable {
                case character
                case outfit
                case gunSkin
                case emote
                case effect
                case powerup
                case booster
                case resource
                case special
                
                var displayName: String {
                    switch self {
                    case .character: return "Character"
                    case .outfit: return "Outfit"
                    case .gunSkin: return "Gun Skin"
                    case .emote: return "Emote"
                    case .effect: return "Effect"
                    case .powerup: return "Power-up"
                    case .booster: return "Booster"
                    case .resource: return "Resource"
                    case .special: return "Special Item"
                    }
                }
            }
            
            enum Rarity: String, Codable {
                case common
                case uncommon
                case rare
                case epic
                case legendary
                case unique
                
                var marketFee: Double {
                    switch self {
                    case .common: return 0.05
                    case .uncommon: return 0.07
                    case .rare: return 0.10
                    case .epic: return 0.12
                    case .legendary: return 0.15
                    case .unique: return 0.20
                    }
                }
            }
        }
        
        struct Price: Codable {
            let amount: Int
            let currency: Currency
            
            enum Currency: String, Codable {
                case coins
                case gems
                case special
            }
        }
        
        enum Status: String, Codable {
            case active
            case sold
            case expired
            case cancelled
        }
    }
    
    struct MarketStats: Codable {
        let totalListings: Int
        let activeListings: Int
        let averagePrices: [String: Int]
        let popularItems: [PopularItem]
        let volumeStats: VolumeStats
        
        struct PopularItem: Codable {
            let itemId: String
            let sales: Int
            let averagePrice: Int
            let trend: Trend
            
            enum Trend: String, Codable {
                case rising
                case falling
                case stable
            }
        }
        
        struct VolumeStats: Codable {
            let daily: Int
            let weekly: Int
            let monthly: Int
            let totalVolume: Int
        }
    }
    
    struct Transaction: Codable {
        let id: String
        let listingId: String
        let buyerId: String
        let sellerId: String
        let item: Listing.MarketItem
        let price: Listing.Price
        let quantity: Int
        let timestamp: Date
        let status: Status
        
        enum Status: String, Codable {
            case pending
            case completed
            case failed
            case refunded
        }
    }
    
    // MARK: - Initialization
    private init() {
        setupRefreshTimer()
        loadMarketData()
    }
    
    private func setupRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 60, // 1 minute
            repeats: true
        ) { [weak self] _ in
            self?.refreshMarket()
        }
    }
    
    // MARK: - Listing Management
    func createListing(
        item: Listing.MarketItem,
        price: Listing.Price,
        quantity: Int,
        duration: TimeInterval,
        completion: @escaping (Result<Listing, Error>) -> Void
    ) {
        let listing = Listing(
            id: UUID().uuidString,
            sellerId: playerStats.userId,
            item: item,
            price: price,
            quantity: quantity,
            expiryDate: Date().addingTimeInterval(duration),
            status: .active,
            tags: generateTags(for: item),
            timestamp: Date()
        )
        
        Task {
            do {
                let response: Listing = try await networkManager.request(
                    endpoint: "marketplace/listings",
                    method: .post,
                    parameters: ["listing": listing]
                )
                
                activeListings.append(response)
                userListings.append(response)
                
                analytics.trackEvent(.featureUsed(name: "market_listing_created"))
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func cancelListing(
        _ listingId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                try await networkManager.request(
                    endpoint: "marketplace/listings/\(listingId)/cancel",
                    method: .post
                )
                
                // Update local state
                updateListingStatus(listingId, .cancelled)
                
                analytics.trackEvent(.featureUsed(name: "market_listing_cancelled"))
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func purchaseItem(
        _ listingId: String,
        quantity: Int,
        completion: @escaping (Result<Transaction, Error>) -> Void
    ) {
        Task {
            do {
                let transaction: Transaction = try await networkManager.request(
                    endpoint: "marketplace/purchase",
                    method: .post,
                    parameters: [
                        "listing_id": listingId,
                        "quantity": quantity
                    ]
                )
                
                if transaction.status == .completed {
                    // Update listing status
                    updateListingStatus(listingId, .sold)
                    
                    // Grant item to buyer
                    grantPurchasedItem(transaction)
                }
                
                analytics.trackEvent(.purchase(
                    item: transaction.item.id,
                    price: transaction.price.amount
                ))
                
                completion(.success(transaction))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Watchlist Management
    func addToWatchlist(_ listingId: String) {
        watchlist.insert(listingId)
        saveWatchlist()
        
        analytics.trackEvent(.featureUsed(name: "market_watchlist_add"))
    }
    
    func removeFromWatchlist(_ listingId: String) {
        watchlist.remove(listingId)
        saveWatchlist()
    }
    
    // MARK: - Market Data
    private func loadMarketData() {
        Task {
            do {
                // Load active listings
                let listings: [Listing] = try await networkManager.request(
                    endpoint: "marketplace/listings"
                )
                activeListings = listings
                
                // Load user listings
                let userListings: [Listing] = try await networkManager.request(
                    endpoint: "marketplace/listings/user"
                )
                self.userListings = userListings
                
                // Load market stats
                let stats: MarketStats = try await networkManager.request(
                    endpoint: "marketplace/stats"
                )
                marketStats = stats
                
                // Load watchlist
                loadWatchlist()
            } catch {
                print("Failed to load market data: \(error.localizedDescription)")
            }
        }
    }
    
    private func refreshMarket() {
        loadMarketData()
    }
    
    // MARK: - Helpers
    private func updateListingStatus(_ listingId: String, _ status: Listing.Status) {
        if let index = activeListings.firstIndex(where: { $0.id == listingId }) {
            var listing = activeListings[index]
            listing.status = status
            activeListings[index] = listing
        }
        
        if let index = userListings.firstIndex(where: { $0.id == listingId }) {
            var listing = userListings[index]
            listing.status = status
            userListings[index] = listing
        }
    }
    
    private func grantPurchasedItem(_ transaction: Transaction) {
        switch transaction.item.type {
        case .character:
            CharacterManager.shared.unlockCharacter(transaction.item.id)
        case .outfit, .gunSkin, .emote, .effect:
            CustomizationManager.shared.unlockItem(
                transaction.item.id,
                type: .init(rawValue: transaction.item.type.rawValue)!
            )
        case .powerup:
            PowerupManager.shared.addPowerup(transaction.item.id)
        case .booster:
            // Handle booster activation
            break
        case .resource:
            // Handle resource addition
            break
        case .special:
            // Handle special items
            break
        }
    }
    
    private func generateTags(for item: Listing.MarketItem) -> [String] {
        var tags = [
            item.type.rawValue,
            item.rarity.rawValue
        ]
        
        // Add additional tags based on metadata
        if let category = item.metadata["category"] {
            tags.append(category)
        }
        
        return tags
    }
    
    // MARK: - Persistence
    private func saveWatchlist() {
        UserDefaults.standard.set(Array(watchlist), forKey: "marketWatchlist")
    }
    
    private func loadWatchlist() {
        if let watchlist = UserDefaults.standard.array(forKey: "marketWatchlist") as? [String] {
            self.watchlist = Set(watchlist)
        }
    }
    
    // MARK: - Cleanup
    func cleanup() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        activeListings.removeAll()
        userListings.removeAll()
        watchlist.removeAll()
        marketStats = nil
    }
}

// MARK: - Convenience Methods
extension MarketplaceManager {
    func getActiveListings(
        type: Listing.MarketItem.ItemType? = nil,
        rarity: Listing.MarketItem.Rarity? = nil
    ) -> [Listing] {
        return activeListings.filter {
            $0.status == .active &&
            (type == nil || $0.item.type == type) &&
            (rarity == nil || $0.item.rarity == rarity)
        }
    }
    
    func getUserListings() -> [Listing] {
        return userListings
    }
    
    func getWatchlistItems() -> [Listing] {
        return activeListings.filter { watchlist.contains($0.id) }
    }
    
    func getAveragePrice(for itemId: String) -> Int? {
        return marketStats?.averagePrices[itemId]
    }
    
    func getMarketTrend(for itemId: String) -> MarketStats.PopularItem.Trend? {
        return marketStats?.popularItems.first { $0.itemId == itemId }?.trend
    }
    
    func calculateMarketFee(_ price: Int, rarity: Listing.MarketItem.Rarity) -> Int {
        return Int(Double(price) * rarity.marketFee)
    }
}
