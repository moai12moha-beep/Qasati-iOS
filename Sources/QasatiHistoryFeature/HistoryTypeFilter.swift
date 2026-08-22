import QasatiDomain

/// فلتر نوع العملية في شاشة السجل — مفهوم UI فقط؛ `Transaction` نفسه لا يكون "الكل" أبدًا،
/// فهذا ليس تعديلًا أو توسيعًا لـ `TransactionType`. يطابق قيم data-filter في
/// qasati-standalone_2.html: all|deposit|withdraw.
public enum HistoryTypeFilter: String, CaseIterable, Equatable, Sendable {
    case all
    case deposit
    case withdraw

    /// `nil` لحالة "الكل" فقط، وإلا `TransactionType` المطابق تمامًا.
    public var transactionType: TransactionType? {
        switch self {
        case .all: return nil
        case .deposit: return .deposit
        case .withdraw: return .withdraw
        }
    }
}
