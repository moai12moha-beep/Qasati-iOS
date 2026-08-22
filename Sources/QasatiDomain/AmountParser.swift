/// يطابق `parseAmountInput()` وقواعد التحقق من صحة المبلغ الموجودة فعليًا في
/// qasati-standalone_2.html. مستقل تمامًا عن أي UI.
public enum AmountParser {

    /// يطابق `parseAmountInput()` حرفيًا: يُبقي فقط الأرقام اللاتينية 0-9 من النص المُدخل
    /// ويحذف أي شيء آخر (فواصل الآلاف، مسافات، إشارة سالبة، أرقام عربية هندية) قبل التحويل
    /// إلى عدد صحيح. لا يوجد دعم للأرقام العربية الهندية في المصدر — نُقل هذا الغياب كما هو،
    /// وليس بافتراض جديد (راجع Data Integrity، القسم 3 من التدقيق).
    ///
    /// يُعيد `nil` عند عدم وجود أي رقم صالح، مطابقًا لحالة `NaN` في JS.
    public static func parse(_ input: String) -> Int? {
        let digitsOnly = input.filter { $0.isASCII && $0.isNumber }
        guard !digitsOnly.isEmpty else { return nil }
        return Int(digitsOnly)
    }

    /// يطابق الشرط المتكرر في `handleDepositSubmit`/`handleWithdrawSubmit`/`saveEdit`
    /// وفي `isValidTransactionShape`: المبلغ صالح فقط إن كان أكبر من صفر تمامًا.
    /// لا حد أقصى للمبلغ في المصدر، فلا حد أقصى هنا.
    public static func isValidAmount(_ amount: Int) -> Bool {
        amount > 0
    }
}
