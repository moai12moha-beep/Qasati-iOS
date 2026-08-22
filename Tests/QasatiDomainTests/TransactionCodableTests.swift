import XCTest
@testable import QasatiDomain

/// يتحقق أن `Transaction` يبقى متوافقًا مع صيغة JSON الحالية القادمة من نسخة الويب:
/// {app:"qasati", version:1, exportedAt, transactions:[{id,type,amount,note,dateISO,seq}]}
/// هذا الملف لا يُنشئ BackupService (مؤجَّل إلى Phase 9) — فقط يتحقق من توافق النوع نفسه.
final class TransactionCodableTests: XCTestCase {

    func test_decodesLegacyWebJSON_transactionsArray() throws {
        let json = """
        [
          {
            "id": "tx_lz9k3f2_ab12cd",
            "type": "deposit",
            "amount": 500000,
            "note": "راتب شهر آب",
            "dateISO": "2026-08-01T08:30:00.000Z",
            "seq": 1735689000123.456
          },
          {
            "id": "tx_lz9k4a1_ef34gh",
            "type": "withdraw",
            "amount": 100000,
            "note": "",
            "dateISO": "2026-08-02T10:15:30.500Z",
            "seq": 1735775400500.789
          }
        ]
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode([Transaction].self, from: json)

        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].id, "tx_lz9k3f2_ab12cd")
        XCTAssertEqual(decoded[0].type, .deposit)
        XCTAssertEqual(decoded[0].amount, 500_000)
        XCTAssertEqual(decoded[0].note, "راتب شهر آب")
        XCTAssertEqual(decoded[0].seq, 1735689000123.456)

        XCTAssertEqual(decoded[1].type, .withdraw)
        XCTAssertEqual(decoded[1].note, "")
    }

    func test_decodesDateWithoutFractionalSeconds_asDefensiveFallback() throws {
        let json = """
        {"id":"tx_1","type":"deposit","amount":1000,"note":"","dateISO":"2026-08-01T08:30:00Z","seq":1}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(Transaction.self, from: json)
        XCTAssertEqual(decoded.amount, 1000)
    }

    func test_encodeThenDecode_roundTripsExactly() throws {
        let original = Transaction(
            id: "tx_roundtrip",
            type: .withdraw,
            amount: 42_000,
            note: "اختبار الجولة الكاملة",
            dateISO: Date(timeIntervalSince1970: 1_755_000_000),
            seq: 1_755_000_000_123.456
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Transaction.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.amount, original.amount)
        XCTAssertEqual(decoded.note, original.note)
        XCTAssertEqual(decoded.seq, original.seq)
        XCTAssertEqual(
            decoded.dateISO.timeIntervalSince1970,
            original.dateISO.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func test_missingNote_decodesAsEmptyString() throws {
        let json = """
        {"id":"tx_1","type":"deposit","amount":1000,"dateISO":"2026-08-01T08:30:00.000Z","seq":1}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(Transaction.self, from: json)
        XCTAssertEqual(decoded.note, "")
    }
}
