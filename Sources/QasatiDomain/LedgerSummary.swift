/// ملخص مشتق بالكامل من سجل العمليات، يطابق شكل القيمة التي تُعيدها
/// دالة `getSummary()` في qasati-standalone_2.html.
public struct LedgerSummary: Equatable, Sendable {
    public let balance: Int
    public let totalDeposits: Int
    public let totalWithdrawals: Int
    public let countIn: Int
    public let countOut: Int

    /// صافي (إيداعات - سحوبات) الشهر المرجعي فقط (وليس تراكميًا).
    public let monthNet: Int

    public init(
        balance: Int,
        totalDeposits: Int,
        totalWithdrawals: Int,
        countIn: Int,
        countOut: Int,
        monthNet: Int
    ) {
        self.balance = balance
        self.totalDeposits = totalDeposits
        self.totalWithdrawals = totalWithdrawals
        self.countIn = countIn
        self.countOut = countOut
        self.monthNet = monthNet
    }
}
