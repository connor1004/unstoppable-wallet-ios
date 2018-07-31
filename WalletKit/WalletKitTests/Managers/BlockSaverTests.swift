import XCTest
import Cuckoo
import RealmSwift
@testable import WalletKit

class BlockSaverTests: XCTestCase {

    private var mockRealmFactory: MockRealmFactory!
    private var saver: BlockSaver!

    private var realm: Realm!
    private var initialBlock: Block!

    override func setUp() {
        super.setUp()

        mockRealmFactory = MockRealmFactory()
        saver = BlockSaver(realmFactory: mockRealmFactory)

        realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "TestRealm"))
        try! realm.write { realm.deleteAll() }

        initialBlock = BlockCreator.shared.create(withHeader: TestHelper.checkpointBlockHeader, height: 1)

        try! realm.write {
            realm.add(initialBlock)
        }

        stub(mockRealmFactory) { mock in
            when(mock.realm.get).thenReturn(realm)
        }
    }

    override func tearDown() {
        mockRealmFactory = nil
        saver = nil

        realm = nil
        initialBlock = nil

        super.tearDown()
    }

    func testSave() {
        let block1 = BlockCreator.shared.create(
                withHeader: BlockHeader(version: 536870912, previousBlockHeaderReversedHex: "000000000000837bcdb53e7a106cf0e74bab6ae8bc96481243d31bea3e6b8c92", merkleRootReversedHex: "8beab73ba2318e4cbdb1c65624496bc3214d6ba93204e049fb46293a41880b9a", timestamp: 1506023937, bits: 453021074, nonce: 2001025151),
                previousBlock: initialBlock
        )
        let block2 = BlockCreator.shared.create(
                withHeader: BlockHeader(version: 536870912, previousBlockHeaderReversedHex: "00000000000025c23a19cc91ad8d3e33c2630ce1df594e1ae0bf0eabe30a9176", merkleRootReversedHex: "63241c065cf8240ac64772e064a9436c21dc4c75843e7e5df6ecf41d5ef6a1b4", timestamp: 1506024043, bits: 453021074, nonce: 1373615473),
                previousBlock: block1
        )

        try! saver.create(blocks: [block1, block2])

        let blocks = realm.objects(Block.self)

        XCTAssertEqual(blocks.count, 1 + 2)
        XCTAssertEqual(blocks[1].previousBlock, initialBlock)
        XCTAssertEqual(blocks[2].previousBlock, blocks[1])
    }

    func testUpdateWithMerkleBlock() {
        let blockHeader = BlockHeader(version: 536870912, previousBlockHeaderReversedHex: "000000000000837bcdb53e7a106cf0e74bab6ae8bc96481243d31bea3e6b8c92", merkleRootReversedHex: "8beab73ba2318e4cbdb1c65624496bc3214d6ba93204e049fb46293a41880b9a", timestamp: 1506023937, bits: 453021074, nonce: 2001025151)
        let hashes = [
            "f0db27cd89551bd197bf551bf697d6eab8fea1fae982fe4b0055fdd58b1f7ee0".reversedData!,
            "86fef17ab1b91ffd8e9e9b14823539e4a22116a078cda1de6e31ddbcbd070993".reversedData!
        ]
        let message = MerkleBlockMessage(blockHeader: blockHeader, totalTransactions: 1, numberOfHashes: 2, hashes: hashes, numberOfFlags: 3, flags: [1, 0, 0])

        let block = BlockCreator.shared.create(withHeader: blockHeader, previousBlock: initialBlock)

        try! saver.create(blocks: [block])

        guard let savedBlock = realm.objects(Block.self).last else {
            XCTFail("Block not saved!")
            return
        }

        try! saver.update(block: savedBlock, withTransactionHashes: message.hashes)
        let transactions = realm.objects(Transaction.self)

        XCTAssertEqual(savedBlock.transactions.count, transactions.count)
        for (i, transaction) in transactions.enumerated() {
            XCTAssertEqual(savedBlock.transactions[i].reversedHashHex, hashes[i].reversedHex)
        }

        XCTAssertTrue(savedBlock.synced)
    }

}
