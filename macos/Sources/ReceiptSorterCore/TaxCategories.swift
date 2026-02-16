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

import Foundation

public enum TaxCategoryType: String, CaseIterable, Sendable {
  case canadian
  case us
}

public struct TaxCategories: Sendable {

  public static let canadian: [String] = [
    "Office Expenses",
    "Meals & Entertainment",
    "Travel",
    "Vehicle Expenses",
    "Professional Services",
    "Marketing & Advertising",
    "Utilities & Rent",
    "Insurance",
    "Education & Training",
    "Other",
  ]

  public static let us: [String] = [
    "Advertising",
    "Vehicle Expenses",
    "Commissions & Fees",
    "Contract Labor",
    "Insurance",
    "Interest",
    "Legal & Professional Services",
    "Office Expenses",
    "Rent & Lease",
    "Repairs & Maintenance",
    "Supplies",
    "Taxes & Licenses",
    "Travel",
    "Meals",
    "Utilities",
    "Other",
  ]

  public static func forCurrency(_ currency: String?) -> [String] {
    guard let currency = currency?.uppercased() else {
      return canadian  // Default to Canadian
    }

    if currency == "USD" {
      return us
    } else {
      return canadian
    }
  }
}
