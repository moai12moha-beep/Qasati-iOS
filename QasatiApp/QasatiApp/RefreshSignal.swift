import Observation

/// إشارة إعادة تحميل مشتركة بحتة — لا تُخزّن أي بيانات مالية، فقط عدّاد إصدار يزداد بعد
/// كل عملية تعديل ناجحة على البيانات المُخزَّنة. أي شاشة تعرض بيانات مشتقّة من السجل
/// المالي تراقب `version` وتعيد التحميل من الحقيقة المخزَّنة عند تغيّره. لا NotificationCenter،
/// لا أسماء نصية، لا حالة مالية مكرَّرة هنا.
@Observable
final class RefreshSignal {
    private(set) var version: Int = 0

    func bump() {
        version += 1
    }
}
