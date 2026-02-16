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
