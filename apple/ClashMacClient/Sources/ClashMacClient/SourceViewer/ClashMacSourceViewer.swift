import AppKit
import ClashClientKit
import ClashClientUI
import SwiftUI

 
 
 
 
 
@MainActor
public final class ClashMacSourceViewerModel: ObservableObject {
    public enum Phase: Equatable {
        case counting
        case ready
        case failed
    }

     
    public struct Reveal: Equatable {
        public let line: Int
        let serial: Int
         
         
        let selects: Bool
         
        var match: ConfigurationSourceMatch?
    }

     
     
     
    public static let matchCap = 100_000

    @Published public private(set) var phase: Phase = .counting
    @Published public private(set) var byteCount = 0
    @Published public private(set) var matches: [ConfigurationSourceMatch] = []
    @Published public private(set) var isSearching = false
    @Published public private(set) var hasMoreMatches = false
    @Published public private(set) var current: Int?
    @Published public private(set) var reveal: Reveal?
     
    @Published public var query = "" {
        didSet { if query != oldValue { scheduleSearch() } }
    }

    public var lineCount: Int { index?.lineCount ?? 0 }
     
    public var longestLineBytes: Int { index?.longestLineBytes ?? 0 }
    public var sections: [ConfigurationSourceSection] { index?.sections ?? [] }

    private let url: URL
    private let matchCap: Int
    private var text: ConfigurationSourceText?
    private var index: ConfigurationSourceIndex?
    private var byLine: [Int: [ConfigurationSourceMatch]] = [:]
    private var searchTask: Task<Void, Never>?
    private var pendingSearch: Task<Void, Never>?
    private var generation = 0
    private var serial = 0

    public init(url: URL, matchCap: Int = ClashMacSourceViewerModel.matchCap) {
        self.url = url
        self.matchCap = matchCap
    }

     
    public func open() async {
        guard index == nil else { return }
        let url = url
        let opened = await Task.detached(priority: .userInitiated) { () -> (ConfigurationSourceText, ConfigurationSourceIndex)? in
            guard let text = try? ConfigurationSourceText(contentsOf: url),
                  let index = try? text.buildIndex() else { return nil }
            return (text, index)
        }.value
        guard let opened else {
            phase = .failed
            return
        }
        (text, index) = opened
        byteCount = opened.0.byteCount
        phase = .ready
    }

     
    public func line(_ number: Int) -> String {
        guard let text, let index, number >= 0, number < index.lineCount else { return "" }
        return text.line(number, in: index)
    }

    public func matches(onLine number: Int) -> [ConfigurationSourceMatch] {
        byLine[number] ?? []
    }

     
    public var currentMatch: ConfigurationSourceMatch? {
        current.flatMap { matches.indices.contains($0) ? matches[$0] : nil }
    }

    public func next() { step(by: 1) }

    public func previous() { step(by: -1) }

     
    public func goTo(lineNumber: Int) {
        guard lineCount > 0 else { return }
        show(line: min(max(lineNumber, 1), lineCount) - 1, selects: true)
    }

    public func show(_ section: ConfigurationSourceSection) {
        show(line: section.line, selects: true)
    }

     
     
    public func search(_ query: String) async {
        pendingSearch?.cancel()
        searchTask?.cancel()
        generation &+= 1
        let generation = generation
        matches = []
        byLine = [:]
        current = nil
        hasMoreMatches = false
        guard !query.isEmpty, let text, let index else {
            isSearching = false
            return
        }
        isSearching = true
        let cap = matchCap
        let task = Task.detached(priority: .userInitiated) { [weak self] in
            var kept = 0
             
             
            try? text.search(query, in: index, batchSize: 512) { batch in
                guard kept < cap else { return }
                let taken = Array(batch.prefix(cap - kept))
                kept += taken.count
                let full = kept >= cap
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { self?.take(taken, full: full, generation: generation) }
                }
                if full { withUnsafeCurrentTask { $0?.cancel() } }
            }
            await MainActor.run { self?.finish(generation) }
        }
        searchTask = task
        await task.value
    }

     
    public func stopSearching() {
        query = ""
    }

    private func scheduleSearch() {
        pendingSearch?.cancel()
        let query = query
        pendingSearch = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            await self?.search(query)
        }
    }

    private func take(_ batch: [ConfigurationSourceMatch], full: Bool, generation: Int) {
        guard generation == self.generation, !batch.isEmpty else { return }
        matches.append(contentsOf: batch)
        for match in batch { byLine[match.line, default: []].append(match) }
        if full { hasMoreMatches = true }
        if current == nil {
            current = 0
            show(line: batch[0].line, selects: false, match: batch[0])
        }
    }

    private func finish(_ generation: Int) {
        guard generation == self.generation else { return }
        isSearching = false
    }

    private func step(by offset: Int) {
        guard !matches.isEmpty else { return }
        let count = matches.count
        let next = ((current ?? -offset) + offset + count) % count
        current = next
        show(line: matches[next].line, selects: false, match: matches[next])
    }

    private func show(line: Int, selects: Bool, match: ConfigurationSourceMatch? = nil) {
        serial &+= 1
        reveal = Reveal(line: line, serial: serial, selects: selects, match: match)
    }
}

 
 
struct ClashMacSourceViewerTable: NSViewRepresentable {
    @ObservedObject var model: ClashMacSourceViewerModel
    @Environment(\.locale) private var locale

    static let numberColumn = NSUserInterfaceItemIdentifier("number")
    static let textColumn = NSUserInterfaceItemIdentifier("text")

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeNSView(context: Context) -> NSScrollView {
        let table = ClashMacSourceLinesTable()
        table.headerView = nil
        table.style = .plain
        table.rowHeight = Coordinator.rowHeight
        table.intercellSpacing = .zero
        table.gridStyleMask = []
        table.allowsMultipleSelection = true
        table.columnAutoresizingStyle = .noColumnAutoresizing
        table.backgroundColor = .textBackgroundColor
        let number = NSTableColumn(identifier: Self.numberColumn)
        number.width = 56
        table.addTableColumn(number)
        let text = NSTableColumn(identifier: Self.textColumn)
        text.width = 1_200
        table.addTableColumn(text)
        table.dataSource = context.coordinator
        table.delegate = context.coordinator
        table.lines = { [weak coordinator = context.coordinator] rows in
            rows.map { coordinator?.model.line($0) ?? "" }
        }
        let menu = NSMenu()
        let copy = NSMenuItem(title: ClashCopy.string("Copy Line", locale: locale),
                              action: #selector(ClashMacSourceLinesTable.copyClickedLines(_:)), keyEquivalent: "")
        copy.target = table
        menu.addItem(copy)
        table.menu = menu
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = true
        scroll.backgroundColor = .textBackgroundColor
        context.coordinator.table = table
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.model = model
        context.coordinator.apply()
    }

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        static let rowHeight: CGFloat = 17
         
        static let textInset: CGFloat = 12
        static let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
         
        static let advance = ("0" as NSString).size(withAttributes: [.font: font]).width

        var model: ClashMacSourceViewerModel
        weak var table: NSTableView?
        private var shownLines = -1
        private var shownMatches = 0
        private var shownCurrent: Int?
        private var shownReveal: ClashMacSourceViewerModel.Reveal?

        init(model: ClashMacSourceViewerModel) {
            self.model = model
        }

         
         
        func apply() {
            guard let table else { return }
            if shownLines != model.lineCount {
                shownLines = model.lineCount
                let digits = String(max(model.lineCount, 1)).count
                table.tableColumns.first?.width = CGFloat(digits) * Self.advance + 20
                 
                 
                 
                table.tableColumns.last?.width = min(max(CGFloat(model.longestLineBytes) * Self.advance + 24, 600), 40_000)
                table.reloadData()
            } else if shownMatches != model.matches.count || shownCurrent != model.current {
                let visible = table.rows(in: table.visibleRect)
                if visible.length > 0 {
                    table.reloadData(forRowIndexes: IndexSet(integersIn: visible.location..<NSMaxRange(visible)),
                                     columnIndexes: IndexSet(integer: 1))
                }
            }
            shownMatches = model.matches.count
            shownCurrent = model.current
            if let reveal = model.reveal, reveal != shownReveal, reveal.line < table.numberOfRows {
                shownReveal = reveal
                scroll(to: reveal, in: table)
                if reveal.selects { table.selectRowIndexes(IndexSet(integer: reveal.line), byExtendingSelection: false) }
            }
        }

         
         
        private func scroll(to reveal: ClashMacSourceViewerModel.Reveal, in table: NSTableView) {
            guard let clip = table.enclosingScrollView?.contentView else {
                table.scrollRowToVisible(reveal.line)
                return
            }
            let rect = table.rect(ofRow: reveal.line)
            let top = max(rect.minY - clip.bounds.height / 3, 0)
            var x = clip.bounds.minX
            if let match = reveal.match, let span = span(of: match, in: table) {
                if span.lowerBound < clip.bounds.minX || span.upperBound > clip.bounds.maxX {
                     
                     
                    x = span.upperBound <= clip.bounds.width ? 0 : span.lowerBound - clip.bounds.width / 3
                }
            }
            clip.scroll(to: NSPoint(x: min(max(x, 0), max(table.bounds.width - clip.bounds.width, 0)),
                                    y: min(top, max(table.bounds.height - clip.bounds.height, 0))))
            table.enclosingScrollView?.reflectScrolledClipView(clip)
        }

         
         
        private func span(of match: ConfigurationSourceMatch, in table: NSTableView) -> ClosedRange<CGFloat>? {
            let line = model.line(match.line) as NSString
            let range = match.utf16Range(in: line as String)
            guard range.location != NSNotFound, NSMaxRange(range) <= line.length else { return nil }
            let attributes: [NSAttributedString.Key: Any] = [.font: Self.font]
            let start = table.rect(ofColumn: 1).minX + Self.textInset
                + line.substring(to: range.location).size(withAttributes: attributes).width
            return start...(start + line.substring(with: range).size(withAttributes: attributes).width)
        }

        func numberOfRows(in tableView: NSTableView) -> Int { model.lineCount }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let column = tableColumn?.identifier else { return nil }
            let cell = (tableView.makeView(withIdentifier: column, owner: nil) as? NSTableCellView) ?? Self.cell(column)
            if column == ClashMacSourceViewerTable.numberColumn {
                cell.textField?.stringValue = String(row + 1)
            } else {
                let line = model.line(row)
                let drawn = ClashMacSourceLineStyle.attributed(line, matches: model.matches(onLine: row),
                                                               current: model.currentMatch, font: Self.font)
                cell.textField?.attributedStringValue = drawn
            }
            return cell
        }

        private static func cell(_ column: NSUserInterfaceItemIdentifier) -> NSTableCellView {
            let cell = NSTableCellView()
            cell.identifier = column
            let field = NSTextField(labelWithString: "")
            field.font = font
            field.lineBreakMode = .byClipping
            field.usesSingleLineMode = true
            field.isSelectable = false
            field.translatesAutoresizingMaskIntoConstraints = false
            if column == ClashMacSourceViewerTable.numberColumn {
                field.alignment = .right
                field.textColor = .tertiaryLabelColor
            }
            cell.addSubview(field)
            cell.textField = field
            NSLayoutConstraint.activate([
                field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: column == ClashMacSourceViewerTable.numberColumn ? 4 : textInset),
                field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: column == ClashMacSourceViewerTable.numberColumn ? -8 : 0),
                field.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
            return cell
        }
    }
}

 
 
final class ClashMacSourceLinesTable: NSTableView {
    var lines: (([Int]) -> [String])?

    @objc func copy(_ sender: Any?) {
        put(Array(selectedRowIndexes))
    }

    @objc func copyClickedLines(_ sender: Any?) {
        let clicked = clickedRow
        guard clicked >= 0 else { return put(Array(selectedRowIndexes)) }
        put(selectedRowIndexes.contains(clicked) ? Array(selectedRowIndexes) : [clicked])
    }

     
     
     
     
    override func accessibilityChildren() -> [Any]? {
        onScreenRows
    }

     
     
    override func accessibilityRows() -> [NSAccessibilityRow]? {
        onScreenRows
    }

     
     
    @available(macOS, deprecated: 10.10)
    override func accessibilityAttributeValue(_ attribute: NSAccessibility.Attribute) -> Any? {
        switch attribute {
        case .rows, .children, .visibleRows: return onScreenRows
        default: return super.accessibilityAttributeValue(attribute)
        }
    }

    private var onScreenRows: [NSTableRowView] {
        let visible = rows(in: visibleRect)
        guard visible.length > 0 else { return [] }
        return (visible.location..<NSMaxRange(visible)).compactMap { rowView(atRow: $0, makeIfNecessary: false) }
    }

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(copy(_:)) { return !selectedRowIndexes.isEmpty }
        return super.validateUserInterfaceItem(item)
    }

     
     
    private func put(_ rows: [Int]) {
        guard !rows.isEmpty, let lines else { return }
        let text = lines(Array(rows.prefix(100_000))).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

 
 
enum ClashMacSourceLineStyle {
    static func attributed(_ line: String, matches: [ConfigurationSourceMatch],
                           current: ConfigurationSourceMatch?, font: NSFont) -> NSAttributedString {
        let text = NSMutableAttributedString(string: line, attributes: [.font: font, .foregroundColor: NSColor.labelColor])
        for token in ConfigurationSourceHighlight.tokens(in: line) {
            text.addAttribute(.foregroundColor, value: color(token.kind), range: token.range)
        }
        for match in matches {
            let range = match.utf16Range(in: line)
            guard range.location != NSNotFound, NSMaxRange(range) <= text.length else { continue }
            if match == current {
                text.addAttributes([.backgroundColor: NSColor.systemOrange.withAlphaComponent(0.9),
                                    .foregroundColor: NSColor.black], range: range)
            } else {
                text.addAttribute(.backgroundColor, value: matchBackground, range: range)
            }
        }
        return text
    }

    private static let matchBackground = NSColor(name: nil) { appearance in
        NSColor.systemYellow.withAlphaComponent(appearance.isDark ? 0.30 : 0.45)
    }

    private static func color(_ kind: ConfigurationSourceHighlight.Kind) -> NSColor {
        switch kind {
        case .key: return dynamic(light: 0x0B4F79, dark: 0x6BDFFF)
        case .string: return dynamic(light: 0xC41A16, dark: 0xFC6A5D)
        case .literal: return dynamic(light: 0x1C00CF, dark: 0xD0BF69)
        case .comment: return dynamic(light: 0x5D6C79, dark: 0x7F8C98)
        case .punctuation: return .secondaryLabelColor
        }
    }

    private static func dynamic(light: Int, dark: Int) -> NSColor {
        NSColor(name: nil) { appearance in
            let value = appearance.isDark ? dark : light
            return NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                           blue: CGFloat(value & 0xFF) / 255, alpha: 1)
        }
    }
}

private extension NSAppearance {
    var isDark: Bool { bestMatch(from: [.aqua, .darkAqua]) == .darkAqua }
}

 
public struct ClashMacSourceViewer: View {
    @StateObject private var model: ClashMacSourceViewerModel
    private let title: String
    @State private var asksLine = false
    @State private var typedLine = ""
    @Environment(\.locale) private var locale

    public init(url: URL, title: String) {
        _model = StateObject(wrappedValue: ClashMacSourceViewerModel(url: url))
        self.title = title
    }

    public var body: some View {
        content
            .frame(minWidth: 640, minHeight: 480)
            .navigationTitle(Text(verbatim: title))
            .navigationSubtitle(subtitle)
            .searchable(text: $model.query, placement: .toolbar, prompt: Text(clash: .copy("Find in Source")))
            .onSubmit(of: .search) { model.next() }
            .toolbar {
                ToolbarItemGroup {
                    findStatus
                    Button { model.previous() } label: {
                        Label { Text(clash: .copy("Previous Match")) } icon: { Image(systemName: "chevron.up") }
                    }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                    .disabled(model.matches.isEmpty)
                    .help(Text(clash: .copy("Previous Match")))
                    .accessibilityIdentifier("source-viewer.previous")
                    Button { model.next() } label: {
                        Label { Text(clash: .copy("Next Match")) } icon: { Image(systemName: "chevron.down") }
                    }
                    .keyboardShortcut("g", modifiers: .command)
                    .disabled(model.matches.isEmpty)
                    .help(Text(clash: .copy("Next Match")))
                    .accessibilityIdentifier("source-viewer.next")
                }
                ToolbarItem(placement: .primaryAction) { outline }
            }
            .sheet(isPresented: $asksLine) { goToLineSheet }
            .task { await model.open() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .counting:
            ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            Text(clash: .copy("The source could not be opened."))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready:
            ClashMacSourceViewerTable(model: model)
                .accessibilityIdentifier("source-viewer.lines")
        }
    }

     
    private var subtitle: String {
        let size = ByteCountFormatter.string(fromByteCount: Int64(model.byteCount), countStyle: .file)
        guard model.phase == .ready else {
            return model.byteCount > 0 ? size + " · " + ClashCopy.string("Counting lines…", locale: locale)
                : ClashCopy.string("Counting lines…", locale: locale)
        }
        return size + " · " + ClashDisplayText.format("%@ lines", [Self.number(model.lineCount, locale)]).resolved(locale: locale)
    }

     
     
    @ViewBuilder
    private var findStatus: some View {
        if !model.query.isEmpty {
            Group {
                if let current = model.current {
                    Text(verbatim: Self.number(current + 1, locale) + " / " + Self.number(model.matches.count, locale)
                        + (model.isSearching || model.hasMoreMatches ? "+" : ""))
                        .monospacedDigit()
                } else if model.isSearching {
                    Text(clash: .copy("Searching…"))
                } else {
                    Text(clash: .copy("No Results"))
                }
            }
            .foregroundStyle(.secondary)
            .help(model.isSearching ? Text(clash: .copy("Still searching. What's found so far is ready.")) : Text(verbatim: ""))
            .accessibilityIdentifier("source-viewer.find-status")
        }
    }

     
     
    private var outline: some View {
        Menu {
            Button { model.goTo(lineNumber: 1) } label: { Text(clash: .copy("Start of File")) }
            Divider()
            ForEach(model.sections, id: \.line) { section in
                Button { model.show(section) } label: { Text(verbatim: outlineTitle(section)) }
            }
            Divider()
            Button {
                typedLine = ""
                asksLine = true
            } label: { Text(clash: .copy("Go to Line…")) }
                .keyboardShortcut("l", modifiers: .command)
        } label: {
            Label { Text(clash: .copy("Outline")) } icon: { Image(systemName: "list.bullet.indent") }
        }
        .disabled(model.phase != .ready)
        .accessibilityIdentifier("source-viewer.outline")
    }

     
    private func outlineTitle(_ section: ConfigurationSourceSection) -> String {
        var parts = [section.name, ClashDisplayText.format("Line %@", [Self.number(section.line + 1, locale)]).resolved(locale: locale)]
        if section.items > 0 {
            let noun: String
            switch section.name {
            case "proxies": noun = "%@ nodes"
            case "proxy-groups": noun = "%@ groups"
            case "rules": noun = "%@ rules"
            default: noun = "%@ items"
            }
            parts.append(ClashDisplayText.format(noun, [Self.number(section.items, locale)]).resolved(locale: locale))
        }
        return parts.joined(separator: " · ")
    }

    private var goToLineSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(clash: .copy("Go to Line")).font(.headline)
            Text(clash: .format("%@ lines in all", [Self.number(model.lineCount, locale)]))
                .font(.callout)
                .foregroundStyle(.secondary)
            TextField(text: $typedLine) { Text(clash: .copy("Go to Line")) }
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .onSubmit(goToTypedLine)
                .accessibilityIdentifier("source-viewer.go-to-line.field")
            HStack {
                Spacer()
                Button(role: .cancel) { asksLine = false } label: { Text(clash: .copy("Cancel")) }
                    .keyboardShortcut(.cancelAction)
                Button(action: goToTypedLine) { Text(clash: .copy("Go")) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(Int(typedLine.filter(\.isNumber)) == nil)
                    .accessibilityIdentifier("source-viewer.go-to-line.go")
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    private func goToTypedLine() {
        guard let number = Int(typedLine.filter(\.isNumber)) else { return }
        asksLine = false
        model.goTo(lineNumber: number)
    }

    private static func number(_ value: Int, _ locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
