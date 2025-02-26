enum BtcRestoreMode: String, CaseIterable, Identifiable {
    case api
    case blockchain

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .api: return "API"
        case .blockchain: return "sync_mode.from_blockchain".localized
        }
    }

    var description: String {
        switch self {
        case .api: return "btc_restore_mode.recommended".localized
        case .blockchain: return "btc_restore_mode.more_private".localized
        }
    }

}
