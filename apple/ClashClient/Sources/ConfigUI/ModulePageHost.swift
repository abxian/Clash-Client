#if os(iOS) || os(macOS)
import ClashClientUI
import SwiftUI

 
 
 
 
 
 
 
 
struct ModulePageHost: View {
    @ObservedObject var model: ModulePageModel
    @ObservedObject private var addRequest: ModuleAddRequest
     
    @State private var isVisible = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
     
    @Environment(\.clashFeedback) private var feedback

     
    static let pollInterval: UInt64 = 5_000_000_000

    init(model: ModulePageModel) {
        self.model = model
        addRequest = model.addRequest
    }

    var body: some View {
        ClashClientUI.ClashModulesView(
            snapshot: model.snapshot,
            perform: { model.perform($0, feedback: feedback) },
            detail: { model.details[$0] },
            opensAddModule: addRequest.link != nil && isVisible && scenePhase == .active,
            pullToUpdate: { await model.refreshAll() },
            quickAdd: { open in
                ModuleQuickAddCard(
                    isAdding: model.isAdding,
                    refusal: model.addRefusal,
                    add: { input in Task { _ = await model.add(input) } },
                    create: {
                        model.addRefusal = nil
                        open(.manual)
                    }
                )
            }
        ) { mode, dismiss in
            ModuleAddModuleSheet(
                mode: mode,
                isAdding: model.isAdding,
                refusal: model.addRefusal,
                offeredLink: addRequest.link,
                add: { input, name in
                    Task { if await model.add(input, name: name) { dismiss() } }
                },
                cancel: {
                    model.addRefusal = nil
                    dismiss()
                },
                edited: { model.addRefusal = nil }
            )
             
            .onDisappear { addRequest.settle() }
        }
        .onAppear { ModuleTextPlatform.installIfNeeded() }
         
         
         
         
        .clashOnScreen { onScreen in
            isVisible = onScreen
            if onScreen {
                addRequest.pageAppeared()
            } else {
                addRequest.pageDisappeared()
            }
        }
        .task {
            model.locale = locale
             
             
            model.sceneIsActive = scenePhase == .active
            await model.reload()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.pollInterval)
                 
                 
                guard !Task.isCancelled, model.sceneIsActive else { continue }
                await model.refreshRuntime()
            }
        }
        .onChange(of: scenePhase) { phase in
            model.sceneIsActive = phase == .active
            guard phase == .active else { return }
            Task { await model.reload() }
        }
        .onChange(of: locale) { newLocale in
            model.locale = newLocale
            Task { await model.reload() }
        }
    }
}
#endif
