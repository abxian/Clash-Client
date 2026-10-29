import SwiftUI

 
 
 
 
struct ClashProfileRowQuickActions<Icon: View>: ViewModifier {
    let profile: ClashProfileSnapshot
    let enabled: Bool
    let icon: (ClashSymbol) -> Icon
    let update: () -> Void
    let copyLink: () -> Void
    let delete: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
#if os(iOS)
        if enabled {
            content
                 
                 
                .clashSwipeToDelete(identifier: "profile-center.row.delete", profile.canDelete ? delete : nil)
                .contextMenu {
                    if profile.source == .remote, profile.canSync {
                        Button(action: update) {
                            Label { Text("Update") } icon: { icon(.arrowClockwise) }
                        }
                        .accessibilityIdentifier("profile-center.row.update")
                    }
                    if profile.canCopySubscriptionLink {
                        Button(action: copyLink) {
                            Label { Text("Copy Link") } icon: { icon(.link) }
                        }
                        .accessibilityIdentifier("profile-center.row.copy-link")
                    }
                    if profile.canDelete {
                        Button(role: .destructive, action: delete) {
                            Label { Text("Delete") } icon: { icon(.trash) }
                        }
                        .accessibilityIdentifier("profile-center.row.delete-menu")
                    }
                }
        } else {
            content
        }
#else
        content
#endif
    }
}
