import SwiftUI

struct RelativeTimeText: View {
    let date: Date

    var body: some View {
        Text(date, style: .relative)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
