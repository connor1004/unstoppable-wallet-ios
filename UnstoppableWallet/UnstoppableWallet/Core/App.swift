import CurrencyKit
import Foundation
import GRDB
import HsToolKit
import MarketKit
import PinKit
import StorageKit
import ThemeKit

class App {
    static var instance: App?

    static func initApp() throws {
        instance = try App()
    }

    static var shared: App {
        instance!
    }

    let keychainKit: IKeychainKit
    let pinKit: PinKit.Kit

    let currencyKit: CurrencyKit.Kit

    let marketKit: MarketKit.Kit

    let localStorage: LocalStorage

    let themeManager: ThemeManager
    let systemInfoManager: SystemInfoManager

    let pasteboardManager: PasteboardManager
    let reachabilityManager: IReachabilityManager
    let networkManager: NetworkManager

    let accountManager: AccountManager
    let accountRestoreWarningManager: AccountRestoreWarningManager
    let accountFactory: AccountFactory
    let backupManager: BackupManager

    let coinManager: CoinManager

    let evmLabelManager: EvmLabelManager

    let walletManager: WalletManager
    let adapterManager: AdapterManager
    let transactionAdapterManager: TransactionAdapterManager

    let nftMetadataManager: NftMetadataManager
    let nftAdapterManager: NftAdapterManager
    let nftMetadataSyncer: NftMetadataSyncer

    let enabledWalletCacheManager: EnabledWalletCacheManager

    let favoritesManager: FavoritesManager

    let feeCoinProvider: FeeCoinProvider
    let feeRateProviderFactory: FeeRateProviderFactory

    let evmSyncSourceManager: EvmSyncSourceManager
    let evmAccountRestoreStateManager: EvmAccountRestoreStateManager
    let evmBlockchainManager: EvmBlockchainManager
    let tronAccountManager: TronAccountManager

    let restoreSettingsManager: RestoreSettingsManager
    let predefinedBlockchainService: PredefinedBlockchainService

    let logRecordManager: LogRecordManager

    var debugLogger: DebugLogger?
    let logger: Logger

    let appStatusManager: AppStatusManager
    let appVersionManager: AppVersionManager

    let testNetManager: TestNetManager
    let btcBlockchainManager: BtcBlockchainManager

    let kitCleaner: KitCleaner

    let keychainKitDelegate: KeychainKitDelegate
    let pinKitDelegate: PinKitDelegate

    let rateAppManager: RateAppManager
    let guidesManager: GuidesManager
    let termsManager: TermsManager

    let walletConnectSocketConnectionService: WalletConnectSocketConnectionService
    let walletConnectSessionManager: WalletConnectSessionManager
    let walletConnectManager: WalletConnectManager

    let deepLinkManager: DeepLinkManager
    let launchScreenManager: LaunchScreenManager

    let balancePrimaryValueManager: BalancePrimaryValueManager
    let balanceHiddenManager: BalanceHiddenManager
    let balanceConversionManager: BalanceConversionManager

    let appIconManager = AppIconManager()

    let subscriptionManager: SubscriptionManager

    let cexAssetManager: CexAssetManager

    let appManager: AppManager
    let contactManager: ContactBookManager
    let cloudAccountBackupManager: CloudAccountBackupManager

    let appEventHandler = EventHandler()

    init() throws {
        localStorage = LocalStorage(storage: StorageKit.LocalStorage.default)

        let databaseURL = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("bank.sqlite")
        let dbPool = try DatabasePool(path: databaseURL.path)

        try StorageMigrator.migrate(dbPool: dbPool)

        let logRecordStorage = LogRecordStorage(dbPool: dbPool)
        logRecordManager = LogRecordManager(storage: logRecordStorage)

        currencyKit = CurrencyKit.Kit(localStorage: StorageKit.LocalStorage.default)

        marketKit = try MarketKit.Kit.instance(
            hsApiBaseUrl: AppConfig.marketApiUrl,
            cryptoCompareApiKey: AppConfig.cryptoCompareApiKey,
            defiYieldApiKey: AppConfig.defiYieldApiKey,
            hsProviderApiKey: AppConfig.hsProviderApiKey,
            appVersion: AppConfig.appVersion,
            appId: AppConfig.appId,
            minLogLevel: .error
        )
        marketKit.sync()

        logger = Logger(minLogLevel: .error, storage: logRecordManager)
        networkManager = NetworkManager(logger: logger)

        keychainKit = KeychainKit(service: "io.horizontalsystems.bank.dev")

        themeManager = ThemeManager.shared
        systemInfoManager = SystemInfoManager()

        if AppConfig.officeMode {
            debugLogger = DebugLogger(localStorage: localStorage, dateProvider: CurrentDateProvider())
        }

        pasteboardManager = PasteboardManager()
        reachabilityManager = ReachabilityManager()

        let accountRecordStorage = AccountRecordStorage(dbPool: dbPool)
        let accountStorage = AccountStorage(secureStorage: keychainKit.secureStorage, storage: accountRecordStorage)
        let activeAccountStorage = ActiveAccountStorage(dbPool: dbPool)
        let accountCachedStorage = AccountCachedStorage(accountStorage: accountStorage, activeAccountStorage: activeAccountStorage)
        accountManager = AccountManager(storage: accountCachedStorage)
        accountRestoreWarningManager = AccountRestoreWarningManager(accountManager: accountManager, localStorage: StorageKit.LocalStorage.default)
        accountFactory = AccountFactory(accountManager: accountManager)

        cloudAccountBackupManager = CloudAccountBackupManager(ubiquityContainerIdentifier: AppConfig.sharedCloudContainer, logger: logger)
        backupManager = BackupManager(accountManager: accountManager)

        kitCleaner = KitCleaner(accountManager: accountManager)

        let enabledWalletStorage = EnabledWalletStorage(dbPool: dbPool)
        let walletStorage = WalletStorage(marketKit: marketKit, storage: enabledWalletStorage)
        walletManager = WalletManager(accountManager: accountManager, storage: walletStorage)

        coinManager = CoinManager(marketKit: marketKit, walletManager: walletManager)

        let blockchainSettingRecordStorage = try BlockchainSettingRecordStorage(dbPool: dbPool)
        let blockchainSettingsStorage = BlockchainSettingsStorage(storage: blockchainSettingRecordStorage)
        btcBlockchainManager = BtcBlockchainManager(marketKit: marketKit, storage: blockchainSettingsStorage)

        testNetManager = TestNetManager(localStorage: StorageKit.LocalStorage.default)

        let evmSyncSourceStorage = EvmSyncSourceStorage(dbPool: dbPool)
        evmSyncSourceManager = EvmSyncSourceManager(testNetManager: testNetManager, blockchainSettingsStorage: blockchainSettingsStorage, evmSyncSourceStorage: evmSyncSourceStorage)

        let evmAccountRestoreStateStorage = EvmAccountRestoreStateStorage(dbPool: dbPool)
        evmAccountRestoreStateManager = EvmAccountRestoreStateManager(storage: evmAccountRestoreStateStorage)

        let evmAccountManagerFactory = EvmAccountManagerFactory(accountManager: accountManager, walletManager: walletManager, evmAccountRestoreStateManager: evmAccountRestoreStateManager, marketKit: marketKit)
        evmBlockchainManager = EvmBlockchainManager(syncSourceManager: evmSyncSourceManager, testNetManager: testNetManager, marketKit: marketKit, accountManagerFactory: evmAccountManagerFactory)

        let binanceKitManager = BinanceKitManager()
        let tronKitManager = TronKitManager(testNetManager: testNetManager)
        tronAccountManager = TronAccountManager(accountManager: accountManager, walletManager: walletManager, marketKit: marketKit, tronKitManager: tronKitManager, evmAccountRestoreStateManager: evmAccountRestoreStateManager)

        let restoreSettingsStorage = RestoreSettingsStorage(dbPool: dbPool)
        restoreSettingsManager = RestoreSettingsManager(storage: restoreSettingsStorage)
        predefinedBlockchainService = PredefinedBlockchainService(restoreSettingsManager: restoreSettingsManager)

        let hsLabelProvider = HsLabelProvider(networkManager: networkManager)
        let evmLabelStorage = EvmLabelStorage(dbPool: dbPool)
        let syncerStateStorage = SyncerStateStorage(dbPool: dbPool)
        evmLabelManager = EvmLabelManager(provider: hsLabelProvider, storage: evmLabelStorage, syncerStateStorage: syncerStateStorage)

        let adapterFactory = AdapterFactory(
            evmBlockchainManager: evmBlockchainManager,
            evmSyncSourceManager: evmSyncSourceManager,
            binanceKitManager: binanceKitManager,
            btcBlockchainManager: btcBlockchainManager,
            tronKitManager: tronKitManager,
            restoreSettingsManager: restoreSettingsManager,
            coinManager: coinManager,
            evmLabelManager: evmLabelManager
        )
        adapterManager = AdapterManager(
            adapterFactory: adapterFactory,
            walletManager: walletManager,
            evmBlockchainManager: evmBlockchainManager,
            tronKitManager: tronKitManager,
            btcBlockchainManager: btcBlockchainManager
        )
        transactionAdapterManager = TransactionAdapterManager(
            adapterManager: adapterManager,
            evmBlockchainManager: evmBlockchainManager,
            adapterFactory: adapterFactory
        )

        let nftDatabaseStorage = try NftDatabaseStorage(dbPool: dbPool)
        let nftStorage = NftStorage(marketKit: marketKit, storage: nftDatabaseStorage)
        nftMetadataManager = NftMetadataManager(networkManager: networkManager, marketKit: marketKit, storage: nftStorage)
        nftAdapterManager = NftAdapterManager(
            walletManager: walletManager,
            evmBlockchainManager: evmBlockchainManager
        )
        nftMetadataSyncer = NftMetadataSyncer(nftAdapterManager: nftAdapterManager, nftMetadataManager: nftMetadataManager, nftStorage: nftStorage)

        let enabledWalletCacheStorage = EnabledWalletCacheStorage(dbPool: dbPool)
        enabledWalletCacheManager = EnabledWalletCacheManager(storage: enabledWalletCacheStorage, accountManager: accountManager)

        feeCoinProvider = FeeCoinProvider(marketKit: marketKit)
        feeRateProviderFactory = FeeRateProviderFactory()

        let favoriteCoinRecordStorage = FavoriteCoinRecordStorage(dbPool: dbPool)
        favoritesManager = FavoritesManager(storage: favoriteCoinRecordStorage)

        pinKit = PinKit.Kit(secureStorage: keychainKit.secureStorage, localStorage: StorageKit.LocalStorage.default)
        let blurManager = BlurManager(pinKit: pinKit)

        let appVersionRecordStorage = AppVersionRecordStorage(dbPool: dbPool)
        let appVersionStorage = AppVersionStorage(storage: appVersionRecordStorage)

        appStatusManager = AppStatusManager(
            systemInfoManager: systemInfoManager,
            storage: appVersionStorage,
            accountManager: accountManager,
            walletManager: walletManager,
            adapterManager: adapterManager,
            logRecordManager: logRecordManager,
            restoreSettingsManager: restoreSettingsManager,
            evmBlockchainManager: evmBlockchainManager,
            binanceKitManager: binanceKitManager,
            marketKit: marketKit
        )

        appVersionManager = AppVersionManager(systemInfoManager: systemInfoManager, storage: appVersionStorage)

        keychainKitDelegate = KeychainKitDelegate(accountManager: accountManager, walletManager: walletManager)
        keychainKit.set(delegate: keychainKitDelegate)

        pinKitDelegate = PinKitDelegate()
        pinKit.set(delegate: pinKitDelegate)

        rateAppManager = RateAppManager(walletManager: walletManager, adapterManager: adapterManager, localStorage: localStorage)

        guidesManager = GuidesManager(networkManager: networkManager)
        termsManager = TermsManager(storage: StorageKit.LocalStorage.default)

        walletConnectManager = WalletConnectManager(accountManager: accountManager, evmBlockchainManager: evmBlockchainManager)

        let walletClientInfo = WalletConnectClientInfo(
            projectId: AppConfig.walletConnectV2ProjectKey ?? "c4f79cc821944d9680842e34466bfb",
            relayHost: "relay.walletconnect.com",
            name: AppConfig.appName,
            description: "",
            url: AppConfig.appWebPageLink,
            icons: ["https://raw.githubusercontent.com/horizontalsystems/HS-Design/master/PressKit/UW-AppIcon-on-light.png"]
        )

        walletConnectSocketConnectionService = WalletConnectSocketConnectionService(reachabilityManager: reachabilityManager, logger: logger)
        let walletConnectService = WalletConnectService(
            connectionService: walletConnectSocketConnectionService,
            sessionRequestFilterManager: SessionRequestFilterManager(),
            info: walletClientInfo,
            logger: logger
        )
        let walletConnectSessionStorage = WalletConnectSessionStorage(dbPool: dbPool)
        walletConnectSessionManager = WalletConnectSessionManager(service: walletConnectService, storage: walletConnectSessionStorage, accountManager: accountManager, evmBlockchainManager: evmBlockchainManager, currentDateProvider: CurrentDateProvider())

        deepLinkManager = DeepLinkManager()
        launchScreenManager = LaunchScreenManager(storage: StorageKit.LocalStorage.default)

        balancePrimaryValueManager = BalancePrimaryValueManager(localStorage: StorageKit.LocalStorage.default)
        balanceHiddenManager = BalanceHiddenManager(localStorage: StorageKit.LocalStorage.default)
        balanceConversionManager = BalanceConversionManager(marketKit: marketKit, localStorage: StorageKit.LocalStorage.default)

        contactManager = ContactBookManager(localStorage: localStorage, ubiquityContainerIdentifier: AppConfig.privateCloudContainer, helper: ContactBookHelper(), logger: logger)

        subscriptionManager = SubscriptionManager(localStorage: StorageKit.LocalStorage.default, marketKit: marketKit)

        let cexAssetRecordStorage = CexAssetRecordStorage(dbPool: dbPool)
        cexAssetManager = CexAssetManager(accountManager: accountManager, marketKit: marketKit, storage: cexAssetRecordStorage)

        appManager = AppManager(
            accountManager: accountManager,
            walletManager: walletManager,
            adapterManager: adapterManager,
            pinKit: pinKit,
            keychainKit: keychainKit,
            blurManager: blurManager,
            kitCleaner: kitCleaner,
            debugLogger: debugLogger,
            appVersionManager: appVersionManager,
            rateAppManager: rateAppManager,
            logRecordManager: logRecordManager,
            deepLinkManager: deepLinkManager,
            evmLabelManager: evmLabelManager,
            balanceHiddenManager: balanceHiddenManager,
            walletConnectSocketConnectionService: walletConnectSocketConnectionService,
            nftMetadataSyncer: nftMetadataSyncer
        )
    }
}
