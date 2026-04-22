/*
 * ReceiptSorter
 * Copyright (c) 2025 OJD Technical Solutions
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Commercial licensing is available for enterprises.
 * Please contact OJD Technical Solutions for details.
 */

import SwiftUI

/// A receipt data field card that switches to an inline TextField on tap.
/// Calls `onCommit(original, corrected)` when the user confirms an edit.
/// A small orange dot appears on the title when `isCorrected` is true.
struct EditableDataCard: View {
  let title: String
  let icon: String
  let value: String?
  let isCorrected: Bool
  /// Called with (originalValue, newValue) only when they differ and newValue is non-empty.
  let onCommit: (String, String) -> Void

  @State private var isEditing = false
  @State private var editText = ""
  @State private var isHovering = false
  @FocusState private var isFocused: Bool

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      ZStack {
        Circle()
          .fill(.ultraThinMaterial)
          .frame(width: 36, height: 36)
        Image(systemName: icon)
          .foregroundColor(.secondary)
          .font(.system(size: 14))
      }

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 4) {
          Text(title)
            .font(.caption)
            .foregroundColor(.secondary)
          if isCorrected {
            Circle()
              .fill(Color.orange)
              .frame(width: 5, height: 5)
          }
        }

        if isEditing {
          TextField("", text: $editText)
            .font(.body)
            .textFieldStyle(.plain)
            .focused($isFocused)
            .onSubmit { commit() }
            .onChange(of: isFocused) { _, focused in
              if !focused { commit() }
            }
        } else {
          Text(value ?? "Unknown")
            .font(.body)
            .foregroundColor(.primary)
            .contentShape(Rectangle())
            .onTapGesture { startEditing() }
        }
      }

      Spacer()

      if isHovering && !isEditing {
        Image(systemName: "pencil")
          .foregroundColor(.secondary)
          .font(.caption)
          .transition(.opacity)
      }
    }
    .padding(12)
    .background {
      RoundedRectangle(cornerRadius: 12)
        .fill(
          isEditing
            ? AnyShapeStyle(Color.accentColor.opacity(0.05))
            : AnyShapeStyle(.ultraThinMaterial.opacity(0.3))
        )
      RoundedRectangle(cornerRadius: 12)
        .stroke(
          isEditing
            ? AnyShapeStyle(Color.accentColor.opacity(0.4))
            : AnyShapeStyle(
              LinearGradient(
                colors: [.white.opacity(0.1), .white.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            ),
          lineWidth: isEditing ? 1 : 0.5
        )
    }
    .animation(.easeInOut(duration: 0.15), value: isEditing)
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.15)) { isHovering = hovering }
    }
  }

  private func startEditing() {
    editText = value ?? ""
    isEditing = true
    isFocused = true
  }

  private func commit() {
    guard isEditing else { return }
    isEditing = false
    let original = value ?? ""
    let trimmed = editText.trimmingCharacters(in: .whitespaces)
    guard trimmed != original, !trimmed.isEmpty else { return }
    onCommit(original, trimmed)
  }
}
