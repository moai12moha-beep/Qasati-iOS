import XCTest
@testable import QasatiDomain

final class LedgerCalculatorTests: XCTestCase {

    // MARK: - أدوات مساعدة للاختبار

    private func isoDate(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) else {
            XCTFail("تعذر تحليل تاريخ الاختبار: \(iso)")
            return Date(timeIntervalSince1970: 0)
        }
        return date
    }

    private func tx(
        _ id: String,
        _ type: TransactionType,
        _ amount: Int,
        note: String = "",
        date: String,
        seq: Double
    ) -> Transaction {
        Transaction(id: id, type: type, amount: amount, note: note, dateISO: isoDate(date), seq: seq)
    }

    // MARK: - 1) إيداع واحد

    func test_singleDeposit_setsBalanceToAmount() {
        let t = tx("t1", .deposit, 500_000, date: "2026-08-01T08:00:00.000Z", seq: 1)
        let result = LedgerCalculator.recompute([t])

        XCTAssertEqual(result.finalBalance, 500_000)
        XCTAssertEqual(result.ordered.count, 1)
        XCTAssertEqual(result.ordered[0].balanceAfter, 500_000)
    }

    // MARK: - 2) سحب واحد صالح

    func test_validWithdrawal_afterDeposit_reducesBalance() {
        let deposit = tx("t1", .deposit, 500_000, date: "2026-08-01T08:00:00.000Z", seq: 1)
        let withdraw = tx("t2", .withdraw, 100_000, date: "2026-08-02T08:00:00.000Z", seq: 2)

        let result = LedgerCalculator.recompute([deposit, withdraw])

        XCTAssertEqual(result.finalBalance, 400_000)
        XCTAssertEqual(result.ordered.map(\.balanceAfter), [500_000, 400_000])
    }

    // MARK: - 4) سلسلة إيداعات وسحوبات

    func test_sequenceOfDepositsAndWithdrawals_computesCorrectFinalBalance() {
        let txs = [
            tx("t1", .deposit, 500_000, date: "2026-08-01T08:00:00.000Z", seq: 1),
            tx("t2", .withdraw, 100_000, date: "2026-08-02T08:00:00.000Z", seq: 2),
            tx("t3", .deposit, 250_000, date: "2026-08-03T08:00:00.000Z", seq: 3),
            tx("t4", .withdraw, 50_000, date: "2026-08-04T08:00:00.000Z", seq: 4),
            tx("t5", .withdraw, 20_000, date: "2026-08-05T08:00:00.000Z", seq: 5),
        ]

        let result = LedgerCalculator.recompute(txs)

        XCTAssertEqual(result.ordered.map(\.balanceAfter), [500_000, 400_000, 650_000, 600_000, 580_000])
        XCTAssertEqual(result.finalBalance, 580_000)
    }

    // MARK: - 5) الترتيب بواسطة dateISO ثم seq

    func test_recompute_ordersByDateISO_regardlessOfInputOrder() {
        let later = tx("later", .deposit, 100, date: "2026-08-05T08:00:00.000Z", seq: 1)
        let earlier = tx("earlier", .deposit, 200, date: "2026-08-01T08:00:00.000Z", seq: 1)

        // يُدخَل "الأحدث" أولًا عمدًا للتأكد أن الترتيب الناتج يعتمد على dateISO وليس ترتيب الإدخال
        let result = LedgerCalculator.recompute([later, earlier])

        XCTAssertEqual(result.ordered.map(\.transaction.id), ["earlier", "later"])
        XCTAssertEqual(result.ordered.map(\.balanceAfter), [200, 300])
    }

    func test_recompute_tieBreaksBySeq_whenDateISOIsIdentical() {
        let sameDate = "2026-08-01T08:00:00.000Z"
        // seq أكبر يُدخَل أولًا عمدًا؛ يجب أن يُعاد ترتيبه بعد الآخر لأن seq أصغر
        let second = tx("second", .deposit, 100, date: sameDate, seq: 5)
        let first = tx("first", .withdraw, 30, date: sameDate, seq: 2)

        let result = LedgerCalculator.recompute([second, first])

        XCTAssertEqual(result.ordered.map(\.transaction.id), ["first", "second"])
        // first (سحب 30) يُطبَّق أولًا: 0 - 30 = -30، ثم second (إيداع 100): -30 + 100 = 70
        XCTAssertEqual(result.ordered.map(\.balanceAfter), [-30, 70])
    }

    // MARK: - عدة عمليات بنفس التاريخ تمامًا مع اختلاف seq (حالة إضافية صريحة)

    func test_multipleTransactionsOnExactSameDate_orderDeterminedBySeqOnly() {
        let sameDate = "2026-08-10T12:00:00.000Z"
        let a = tx("a", .deposit, 100, date: sameDate, seq: 3)
        let b = tx("b", .deposit, 200, date: sameDate, seq: 1)
        let c = tx("c", .deposit, 300, date: sameDate, seq: 2)

        let result = LedgerCalculator.recompute([a, b, c])

        XCTAssertEqual(result.ordered.map(\.transaction.id), ["b", "c", "a"])
        XCTAssertEqual(result.ordered.map(\.balanceAfter), [200, 500, 600])
    }

    // MARK: - 6) balanceAfter مشتق وليس حالة مخزَّنة

    func test_balanceAfter_isNotPartOfTransactionEncoding() throws {
        let t = tx("t1", .deposit, 500_000, date: "2026-08-01T08:00:00.000Z", seq: 1)

        let data = try JSONEncoder().encode(t)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertNil(json?["balanceAfter"], "Transaction يجب ألا يحتوي balanceAfter مطلقًا في التخزين")
        XCTAssertEqual(Set((json ?? [:]).keys), ["id", "type", "amount", "note", "dateISO", "seq"])
    }

    func test_recompute_isPureAndRepeatable() {
        let txs = [
            tx("t1", .deposit, 500_000, date: "2026-08-01T08:00:00.000Z", seq: 1),
            tx("t2", .withdraw, 100_000, date: "2026-08-02T08:00:00.000Z", seq: 2),
        ]

        let first = LedgerCalculator.recompute(txs)
        let second = LedgerCalculator.recompute(txs)

        XCTAssertEqual(first, second, "استدعاء recompute مرتين بنفس المدخلات يجب أن يُنتج نفس النتيجة تمامًا (بلا حالة مخفية)")
    }

    // MARK: - 7) تعديل عملية بطريقة صحيحة

    func test_applyingEdit_validEdit_succeeds() {
        let deposit = tx("t1", .deposit, 500_000, date: "2026-08-01T08:00:00.000Z", seq: 1)
        let withdraw = tx("t2", .withdraw, 100_000, date: "2026-08-02T08:00:00.000Z", seq: 2)

        let result = LedgerCalculator.applyingEdit(
            to: [deposit, withdraw],
            id: "t1",
            newAmount: 600_000,
            newNote: "راتب معدَّل"
        )

        switch result {
        case .success(let updated):
            let recomputed = LedgerCalculator.recompute(updated)
            XCTAssertEqual(recomputed.finalBalance, 500_000) // 600,000 - 100,000
            let edited = updated.first { $0.id == "t1" }
            XCTAssertEqual(edited?.amount, 600_000)
            XCTAssertEqual(edited?.note, "راتب معدَّل")
            XCTAssertEqual(edited?.dateISO, deposit.dateISO, "dateISO يجب ألا يتغير أبدًا عند التعديل")
        case .failure(let error):
            XCTFail("توقعت نجاح التعديل، لكن فشل بالخطأ: \(error)")
        }
    }

    // MARK: - 8) رفض تعديل ينتج رصيدًا سالبًا في أي نقطة تاريخية

    func test_applyingEdit_rejectsEditThatProducesNegativeBalanceMidHistory() {
        // إيداع 500,000 ثم سحب 400,000 (رصيد لحظي 100,000) ثم إيداع 50,000
        let deposit1 = tx("t1", .deposit, 500_000, date: "2026-08-01T08:00:00.000Z", seq: 1)
        let withdraw = tx("t2", .withdraw, 400_000, date: "2026-08-02T08:00:00.000Z", seq: 2)
        let deposit2 = tx("t3", .deposit, 50_000, date: "2026-08-03T08:00:00.000Z", seq: 3)

        // تخفيض الإيداع الأول إلى 300,000 يجعل الرصيد اللحظي بعد السحب = 300,000 - 400,000 = -100,000
        // رغم أن الرصيد النهائي (300,000 - 400,000 + 50,000 = -50,000) سالب أيضًا هنا،
        // الاختبار يتحقق أن الرفض يحدث بسبب النقطة الوسطى، وليس فقط النهاية.
        let result = LedgerCalculator.applyingEdit(
            to: [deposit1, withdraw, deposit2],
            id: "t1",
            newAmount: 300_000,
            newNote: ""
        )

        XCTAssertEqual(result, .failure(.wouldProduceNegativeBalance))
    }

    func test_applyingEdit_rejectsEditThatOnlyProducesNegativeBalanceMidHistory_notAtEnd() {
        // إيداع 500,000 -> سحب 400,000 (لحظي 100,000) -> إيداع 1,000,000 (نهائي مرتفع جدًا)
        let deposit1 = tx("t1", .deposit, 500_000, date: "2026-08-01T08:00:00.000Z", seq: 1)
        let withdraw = tx("t2", .withdraw, 400_000, date: "2026-08-02T08:00:00.000Z", seq: 2)
        let deposit2 = tx("t3", .deposit, 1_000_000, date: "2026-08-03T08:00:00.000Z", seq: 3)

        // تخفيض الإيداع الأول إلى 350,000: الرصيد اللحظي بعد السحب = 350,000 - 400,000 = -50,000 (سالب)
        // لكن الرصيد النهائي = 350,000 - 400,000 + 1,000,000 = 950,000 (موجب تمامًا)
        // يجب أن يُرفض التعديل رغم أن الرصيد النهائي سليم، لأن نقطة وسطى كانت سالبة.
        let result = LedgerCalculator.applyingEdit(
            to: [deposit1, withdraw, deposit2],
            id: "t1",
            newAmount: 350_000,
            newNote: ""
        )

        XCTAssertEqual(result, .failure(.wouldProduceNegativeBalance))
    }

    func test_applyingEdit_unknownId_returnsNotFound() {
        let deposit = tx("t1", .deposit, 500_000, date: "2026-08-01T08:00:00.000Z", seq: 1)

        let result = LedgerCalculator.applyingEdit(to: [deposit], id: "missing", newAmount: 1, newNote: "")

        XCTAssertEqual(result, .failure(.transactionNotFound))
    }

    // MARK: - 9) حذف عملية ينتج رصيدًا سالبًا → يُرفض (قرار المنتج OQ-1)

    func test_applyingDeletion_rejectsDeletionThatProducesNegativeBalance() {
        let deposit = tx("t1", .deposit, 500_000, date: "2026-08-01T08:00:00.000Z", seq: 1)
        let withdraw = tx("t2", .withdraw, 400_000, date: "2026-08-02T08:00:00.000Z", seq: 2)

        // حذف الإيداع يترك السحب وحده -> رصيد -400,000
        let result = LedgerCalculator.applyingDeletion(from: [deposit, withdraw], id: "t1")

        XCTAssertEqual(result, .failure(.wouldProduceNegativeBalance))
    }

    // MARK: - 10) حذف عملية لا ينتج رصيدًا سالبًا → يُسمح به

    func test_applyingDeletion_allowsDeletionThatKeepsBalanceNonNegative() {
        let deposit1 = tx("t1", .deposit, 500_000, date: "2026-08-01T08:00:00.000Z", seq: 1)
        let deposit2 = tx("t2", .deposit, 200_000, date: "2026-08-02T08:00:00.000Z", seq: 2)
        let withdraw = tx("t3", .withdraw, 100_000, date: "2026-08-03T08:00:00.000Z", seq: 3)

        // حذف deposit2 يترك: إيداع 500,000 ثم سحب 100,000 = رصيد نهائي 400,000 (غير سالب أبدًا)
        let result = LedgerCalculator.applyingDeletion(from: [deposit1, deposit2, withdraw], id: "t2")

        switch result {
        case .success(let remaining):
            XCTAssertEqual(remaining.map(\.id).sorted(), ["t1", "t3"])
            XCTAssertEqual(LedgerCalculator.recompute(remaining).finalBalance, 400_000)
        case .failure(let error):
            XCTFail("توقعت السماح بالحذف، لكن رُفض بالخطأ: \(error)")
        }
    }

    func test_applyingDeletion_unknownId_returnsNotFound() {
        let deposit = tx("t1", .deposit, 500_000, date: "2026-08-01T08:00:00.000Z", seq: 1)

        let result = LedgerCalculator.applyingDeletion(from: [deposit], id: "missing")

        XCTAssertEqual(result, .failure(.transactionNotFound))
    }

    // MARK: - 11) حساب monthNet

    func test_summary_computesMonthNet_forReferenceMonthOnly() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let now = isoDate("2026-08-15T00:00:00.000Z") // الشهر المرجعي: أغسطس 2026

        let inMonthDeposit = tx("t1", .deposit, 500_000, date: "2026-08-01T08:00:00.000Z", seq: 1)
        let inMonthWithdraw = tx("t2", .withdraw, 100_000, date: "2026-08-20T08:00:00.000Z", seq: 2)
        let previousMonthDeposit = tx("t3", .deposit, 999_000, date: "2026-07-01T08:00:00.000Z", seq: 3)
        let nextMonthDeposit = tx("t4", .deposit, 777_000, date: "2026-09-01T08:00:00.000Z", seq: 4)

        let summary = LedgerCalculator.summary(
            for: [inMonthDeposit, inMonthWithdraw, previousMonthDeposit, nextMonthDeposit],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(summary.monthNet, 400_000) // 500,000 - 100,000 فقط، بلا تأثير من الشهرين الآخرين
        XCTAssertEqual(summary.balance, 500_000 - 100_000 + 999_000 + 777_000)
        XCTAssertEqual(summary.totalDeposits, 500_000 + 999_000 + 777_000)
        XCTAssertEqual(summary.totalWithdrawals, 100_000)
        XCTAssertEqual(summary.countIn, 3)
        XCTAssertEqual(summary.countOut, 1)
    }

    // MARK: - 12) سجل فارغ

    func test_emptyLedger_recompute() {
        let result = LedgerCalculator.recompute([])
        XCTAssertEqual(result.finalBalance, 0)
        XCTAssertTrue(result.ordered.isEmpty)
    }

    func test_emptyLedger_summary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = isoDate("2026-08-15T00:00:00.000Z")

        let summary = LedgerCalculator.summary(for: [], now: now, calendar: calendar)

        XCTAssertEqual(summary.balance, 0)
        XCTAssertEqual(summary.totalDeposits, 0)
        XCTAssertEqual(summary.totalWithdrawals, 0)
        XCTAssertEqual(summary.countIn, 0)
        XCTAssertEqual(summary.countOut, 0)
        XCTAssertEqual(summary.monthNet, 0)
    }
}
