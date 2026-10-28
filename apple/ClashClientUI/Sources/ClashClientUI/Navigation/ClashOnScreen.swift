import SwiftUI

public extension View {
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    func clashOnScreen(
        _ change: @escaping @MainActor (_ onScreen: Bool) -> Void
    ) -> some View {
        modifier(ClashOnScreenModifier(change: change))
    }
}

private struct ClashOnScreenModifier: ViewModifier {
    let change: @MainActor (Bool) -> Void
    @StateObject private var teller = ClashOnScreenTeller()

    func body(content: Content) -> some View {
        content
            .onAppear { teller.note(true, change) }
            .onDisappear { teller.note(false, change) }
    }
}

 
 
@MainActor
final class ClashOnScreenTeller: ObservableObject {
    private var onScreen = false
    private var told = false
    private var telling = false
    private var change: (@MainActor (Bool) -> Void)?

    func note(_ onScreen: Bool, _ change: @escaping @MainActor (Bool) -> Void) {
        self.onScreen = onScreen
        self.change = change
        guard !telling else { return }
        telling = true
         
         
        Task { @MainActor in self.tell() }
    }

    private func tell() {
        telling = false
        guard onScreen != told else { return }
        told = onScreen
        change?(onScreen)
    }
}
