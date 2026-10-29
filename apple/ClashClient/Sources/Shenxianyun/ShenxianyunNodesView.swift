import SwiftUI

/// Uses the existing runtime model, including read-back confirmation and the
/// upstream bounded latency-test scheduler. Latency never reorders the cards.
struct ShenxianyunNodesView: View {
    @ObservedObject var nodes: NodesModel
    @Environment(\.dismiss) private var dismiss

    private var group: ProxyGroup? {
        let selectable = nodes.groups.filter { !$0.hidden && $0.acceptsMemberChoice }
        return selectable.first { $0.name == "节点选择" }
            ?? selectable.first { $0.members.contains(where: isAutomatic) }
            ?? selectable.first
    }

    private func isAutomatic(_ name: String) -> Bool {
        guard let item = nodes.groups.first(where: { $0.name == name }) else { return false }
        return ["urltest", "url-test", "fallback", "loadbalance", "load-balance"].contains(item.type.lowercased())
    }

    private func members(_ group: ProxyGroup) -> [String] {
        let visible = group.members.filter { !group.hiddenMembers.contains($0) }
        return visible.filter(isAutomatic) + visible.filter { !isAutomatic($0) }
    }

    var body: some View {
        NavigationView {
            ZStack {
                SXYTheme.canvas
                if let group {
                    VStack(spacing: 12) {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(members(group), id: \.self) { name in
                                    Button {
                                        Task { await nodes.select(group: group.name, name: name) }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Image(systemName: isAutomatic(name) ? "arrow.triangle.2.circlepath" : "globe")
                                                Spacer()
                                                if group.holdsSelection(name) { Image(systemName: "checkmark.circle.fill") }
                                            }
                                            Text(name).font(.subheadline.weight(.semibold)).lineLimit(2)
                                            if let delay = nodes.delays[name], delay > 0 {
                                                Text("\(delay) ms").font(.caption)
                                            } else {
                                                Text(nodes.testingNames.contains(name) ? "测试中" : (nodes.failureReasons[name] ?? "未测试"))
                                                    .font(.caption).lineLimit(2)
                                            }
                                        }
                                        .foregroundStyle(SXYTheme.textSoft)
                                        .padding(14).frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(group.holdsSelection(name) ? SXYTheme.purple : .white, lineWidth: 1.5))
                                    }
                                    .buttonStyle(.plain).disabled(nodes.isSwitchingProxy)
                                    .accessibilityLabel(name + (group.holdsSelection(name) ? "，已选择" : ""))
                                }
                            }
                        }
                        if nodes.actionRefusals[group.name] != nil {
                            Text("切换未成功，请重试或测试连通性").font(.caption).foregroundStyle(SXYTheme.textSoft)
                        }
                        Button { Task { await nodes.test(group: group) } } label: {
                            HStack {
                                if nodes.isTestingLatency { ProgressView() }
                                Text("测试连通性").font(.headline)
                            }.frame(maxWidth: .infinity).padding(14)
                        }.buttonStyle(.bordered).disabled(nodes.isTestingLatency)
                    }.padding(16)
                    .task(id: group.name) { await nodes.loadRemainingMembers(of: group.name) }
                } else {
                    ProgressView("正在读取节点")
                }
            }
            .navigationTitle("选择节点").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
        .navigationViewStyle(.stack)
        .task { await nodes.refresh() }
        .shenxianyunLight()
    }
}
