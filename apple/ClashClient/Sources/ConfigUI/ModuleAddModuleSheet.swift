import ClashClientUI
import SwiftUI

 
 
 
 
 
 
 
 
struct ModuleAddModuleSheet: View {
    enum Input: Equatable {
        case link(String)
        case text(String)
    }

    let isAdding: Bool
    let refusal: ClashDisplayText?
     
     
    let offeredLink: String?
     
    let add: (Input, String) -> Void
    let cancel: () -> Void
    let edited: () -> Void
    @State private var mode: ClashModulesAddMode
    @State private var link: String
     
    @State private var written: String?
    @State private var name = ""
    @Environment(\.locale) private var locale
     
    @Environment(\.clashInsideProductModalPresentation) private var insideProductModal

    init(mode: ClashModulesAddMode = .link, isAdding: Bool, refusal: ClashDisplayText?, offeredLink: String? = nil,
         add: @escaping (Input, String) -> Void, cancel: @escaping () -> Void, edited: @escaping () -> Void) {
        self.isAdding = isAdding
        self.refusal = refusal
        self.offeredLink = offeredLink
        self.add = add
        self.cancel = cancel
        self.edited = edited
        _mode = State(initialValue: offeredLink == nil ? mode : .link)
        _link = State(initialValue: offeredLink ?? "")
    }

    private var typedLink: String { link.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var template: String { ClashModuleEditorSnapshot.template(locale: locale) }
    private var text: String { written ?? template }
    private var isWriting: Bool { written.map { $0 != template } ?? false }

     
    private var input: Input? {
        switch mode {
        case .link: return typedLink.isEmpty ? nil : .link(typedLink)
         
        case .manual: return isWriting && ClashModuleEditorSnapshot.canSave(text) ? .text(text) : nil
        }
    }

    private func confirm() {
        guard !isAdding, let input else { return }
        add(input, name)
    }

    var body: some View {
        ClashClientUI.ClashSingleColumnNavigationContainer {
            Form {
                Section {
                    Picker(selection: $mode) {
                        Text("Link").tag(ClashModulesAddMode.link)
                        Text("Manual").tag(ClashModulesAddMode.manual)
                    } label: {
                        Text("Add Module")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .disabled(isAdding)
                    .accessibilityIdentifier("modules.add.mode")
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                switch mode {
                case .link: linkSection
                case .manual: manualSection
                }
                Section {
                    nameField
                } footer: {
                    Text("Leave blank to use the source's suggested name.")
                }
            }
            .clashPageTitle("Add Module")
            .clashToolbarUnlessInPanel {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: cancel) {
                        Text("Cancel")
                    }
                    .accessibilityIdentifier("modules.add.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isAdding {
                        ProgressView()
                    } else {
                        Button(action: confirm) {
                            Text("Add")
                        }
                        .disabled(input == nil)
                        .accessibilityIdentifier("modules.add.confirm")
                    }
                }
            }
            .clashMacProductModalBar {
                if insideProductModal {
                    ClashModalActionBar(primaryTitle: "Add", primaryDisabled: input == nil, isBusy: isAdding,
                                        onPrimary: confirm)
                }
            }
            .clashProductModalRoot(title: "Add Module", actionTitle: "Add",
                                  actionDisabled: isAdding || input == nil, action: confirm)
        }
         
        .interactiveDismissDisabled(isWriting || isAdding)
    }

    private var linkSection: some View {
        Section {
             
             
             
             
            HStack(spacing: ClashTheme.Spacing.standard) {
                linkField
                ClashPasteControl(style: .square) { pasted in
                    let input = Self.input(forPasted: pasted)
                    if case .link(let value) = input { link = value }
                    add(input, name)
                }
                .disabled(isAdding)
                .accessibilityIdentifier("modules.add.paste")
            }
        } footer: {
            refusalOr(Text("Paste a link to a module, or the module itself."))
        }
    }

     
     
    @ViewBuilder
    private var nameField: some View {
#if os(macOS)
        TextField(text: $name, prompt: Text("Optional")) {
            Text("Name")
        }
        .multilineTextAlignment(.trailing)
        .disabled(isAdding)
        .accessibilityIdentifier("modules.add.name")
#else
        HStack(spacing: ClashTheme.Spacing.standard) {
            Text("Name")
            TextField(text: $name, prompt: Text("Optional")) {
                Text("Name")
            }
            .multilineTextAlignment(.trailing)
            .disabled(isAdding)
            .accessibilityIdentifier("modules.add.name")
        }
#endif
    }

    private var manualSection: some View {
        Section {
            ClashModuleText(text: Binding(get: { text }, set: { written = $0; edited() }), isEditable: !isAdding)
                .frame(height: Self.manualTextHeight)
                .accessibilityLabel(Text("Module Content"))
                .accessibilityIdentifier("modules.add.text")
        } footer: {
            refusalOr(Text("Write the module's name after #!name= on the first line."))
        }
    }

    @ViewBuilder
    private func refusalOr(_ hint: Text) -> some View {
        if let refusal {
            Text(clash: refusal)
                .foregroundStyle(.red)
                .accessibilityIdentifier("modules.add.refusal")
        } else {
            hint
        }
    }

    private var linkField: some View {
        TextField(text: $link, prompt: Self.prompt) {
            Text("Module Link")
        }
        .accessibilityIdentifier("modules.add.link")
        .disableAutocorrection(true)
#if os(iOS)
        .textInputAutocapitalization(.never)
        .keyboardType(.URL)
        .textContentType(.URL)
#endif
        .onChange(of: link) { _ in edited() }
        .onChange(of: offeredLink) { offered in
            if let offered {
                mode = .link
                link = offered
            }
        }
        .onSubmit(confirm)
    }

     
     
    static let manualTextHeight: CGFloat = 240

     
     
     
     
    static var prompt: Text {
        #if os(macOS)
        Text(verbatim: "https://…")
        #else
        Text("Module Link")
        #endif
    }

     
     
    static func input(forPasted pasted: String) -> Input {
        if let carried = ModuleInstallLink.moduleLink(in: pasted) { return .link(carried) }
        let trimmed = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.contains("\n"), let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https", url.host?.isEmpty == false {
            return .link(trimmed)
        }
        return .text(pasted)
    }
}

 
 
 
 
struct ModuleQuickAddCard: View {

    let isAdding: Bool
    let refusal: ClashDisplayText?
    let add: (ModuleAddModuleSheet.Input) -> Void
    let create: () -> Void
    @State private var link = ""

    private var typedLink: String { link.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        Section {
            HStack(spacing: ClashTheme.Spacing.standard) {
                TextField(text: $link, prompt: ModuleAddModuleSheet.prompt) {
                    Text("Module Link")
                }
                .disableAutocorrection(true)
#if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .textContentType(.URL)
#endif
                .submitLabel(.done)
                .onSubmit { if !typedLink.isEmpty { add(.link(typedLink)) } }
                .disabled(isAdding)
                .accessibilityIdentifier("modules.quick-add.link")
                ClashPasteControl(style: .square) { pasted in
                    let input = ModuleAddModuleSheet.input(forPasted: pasted)
                    if case .link(let value) = input { link = value }
                    add(input)
                }
                .disabled(isAdding)
                .accessibilityIdentifier("modules.quick-add.paste")
            }
            if isAdding {
                HStack(spacing: ClashTheme.Spacing.compact) {
                    ProgressView().controlSize(.small)
                    if let host = URL(string: typedLink)?.host {
                        Text(clash: .format("Downloading %@…", [host]))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("modules.quick-add.status")
            } else if let refusal {
                ClashStatusMessage(text: refusal, kind: .error)
                    .accessibilityIdentifier("modules.quick-add.status")
            }
             
             
             
             
            Button(action: create) {
                Label(ClashCopy.key("New Module"), systemImage: ClashSymbol.docBadgePlus.name)
            }
            .disabled(isAdding)
            .accessibilityIdentifier("modules.quick-add.create")
        } header: {
            ClashConfigurationLibraryHeader(title: .copy("Add Module"))
        }
        .onChange(of: isAdding) { adding in
             
            if !adding, refusal == nil { link = "" }
        }
    }
}

 
 
 
 
 
 
 
 
 
enum ModuleInstallLink {
    private static let schemes: Set<String> = [#"clash"#, #"clash"#]
    private static let name = #"install-module"#

     
     
     
    static func moduleLink(from link: URL) -> String? {
        guard let components = URLComponents(url: link, resolvingAgainstBaseURL: false),
              schemes.contains(components.scheme?.lowercased() ?? "") else { return nil }
        let host = components.host?.lowercased() ?? ""
        let path = components.path.lowercased()
        guard host == name && (path.isEmpty || path == #"/"#) || host.isEmpty && path == #"/"# + name else { return nil }
        let carried = components.queryItems?.first(where: { $0.name == #"url"# })?.value ?? ""
        return carried.trimmingCharacters(in: .whitespacesAndNewlines)
    }

     
     
    static func moduleLink(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains("\n"), let url = URL(string: trimmed),
              let carried = moduleLink(from: url), !carried.isEmpty else { return nil }
        return carried
    }
}
