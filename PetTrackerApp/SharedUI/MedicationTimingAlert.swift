import SwiftUI

private struct MedicationTimingAlert: ViewModifier {
    @EnvironmentObject private var store: PetCareStore
    var presentation: MedicationTimingPresentation

    func body(content: Content) -> some View {
        content.alert(item: Binding(
            get: { store.medicationTimingPrompt.flatMap { $0.presentation == presentation ? $0 : nil } },
            set: { value in
                if value == nil, store.medicationTimingPrompt?.presentation == presentation {
                    store.medicationTimingPrompt = nil
                }
            }
        )) { prompt in
            Alert(title: Text("Dose timing warning"), message: Text(prompt.message),
                  primaryButton: .default(Text("Log anyway")) { store.confirmMedicationTimingWrite() },
                  secondaryButton: .cancel(Text("Cancel")) { store.cancelMedicationTimingWrite() })
        }
    }
}

extension View {
    func medicationTimingAlert(_ presentation: MedicationTimingPresentation) -> some View {
        modifier(MedicationTimingAlert(presentation: presentation))
    }
}
