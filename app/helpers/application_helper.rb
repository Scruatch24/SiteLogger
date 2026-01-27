# app/helpers/application_helper.rb
module ApplicationHelper
    def currencies_data
      [
        # PREFIX currencies (symbol before number)
        { n: "US Dollar", c: "USD", s: "$", i: "us", p: "pre" },
        { n: "British Pound", c: "GBP", s: "£", i: "gb", p: "pre" },
        { n: "Japanese Yen", c: "JPY", s: "¥", i: "jp", p: "pre" },
        { n: "Australian Dollar", c: "AUD", s: "A$", i: "au", p: "pre" },
        { n: "Canadian Dollar", c: "CAD", s: "C$", i: "ca", p: "pre" },
        { n: "Chinese Yuan", c: "CNY", s: "¥", i: "cn", p: "pre" },
        { n: "Indian Rupee", c: "INR", s: "₹", i: "in", p: "pre" },
        { n: "Brazilian Real", c: "BRL", s: "R$", i: "br", p: "pre" },
        { n: "Mexican Peso", c: "MXN", s: "$", i: "mx", p: "pre" },
        { n: "Argentine Peso", c: "ARS", s: "$", i: "ar", p: "pre" },
        { n: "Chilean Peso", c: "CLP", s: "$", i: "cl", p: "pre" },
        { n: "Colombian Peso", c: "COP", s: "$", i: "co", p: "pre" },
        { n: "Hong Kong Dollar", c: "HKD", s: "HK$", i: "hk", p: "pre" },
        { n: "Egyptian Pound", c: "EGP", s: "E£", i: "eg", p: "pre" },
        { n: "New Zealand Dollar", c: "NZD", s: "NZ$", i: "nz", p: "pre" },
        { n: "Singapore Dollar", c: "SGD", s: "S$", i: "sg", p: "pre" },
        { n: "Thai Baht", c: "THB", s: "฿", i: "th", p: "pre" },
        { n: "Taiwan Dollar", c: "TWD", s: "NT$", i: "tw", p: "pre" },
        { n: "Philippine Peso", c: "PHP", s: "₱", i: "ph", p: "pre" },
        { n: "South African Rand", c: "ZAR", s: "R", i: "za", p: "pre" },
        { n: "Nigerian Naira", c: "NGN", s: "₦", i: "ng", p: "pre" },
        { n: "Kenyan Shilling", c: "KES", s: "KSh", i: "ke", p: "pre" },
        { n: "Malaysian Ringgit", c: "MYR", s: "RM", i: "my", p: "pre" },
        { n: "Indonesian Rupiah", c: "IDR", s: "Rp", i: "id", p: "pre" },

        # SUFFIX currencies (symbol after number)
        { n: "Euro", c: "EUR", s: "€", i: "eu", p: "suf" },
        { n: "Georgian Lari", c: "GEL", s: "₾", i: "ge", p: "suf" },
        { n: "Turkish Lira", c: "TRY", s: "₺", i: "tr", p: "suf" },
        { n: "Swedish Krona", c: "SEK", s: "kr", i: "se", p: "suf" },
        { n: "Danish Krone", c: "DKK", s: "kr", i: "dk", p: "suf" },
        { n: "Norwegian Krone", c: "NOK", s: "kr", i: "no", p: "suf" },
        { n: "Icelandic Króna", c: "ISK", s: "kr", i: "is", p: "suf" },
        { n: "Polish Zloty", c: "PLN", s: "zł", i: "pl", p: "suf" },
        { n: "Hungarian Forint", c: "HUF", s: "Ft", i: "hu", p: "suf" },
        { n: "Czech Koruna", c: "CZK", s: "Kč", i: "cz", p: "suf" },
        { n: "Romanian Leu", c: "RON", s: "lei", i: "ro", p: "suf" },
        { n: "Vietnamese Dong", c: "VND", s: "₫", i: "vn", p: "suf" },
        { n: "Ukrainian Hryvnia", c: "UAH", s: "₴", i: "ua", p: "suf" },
        { n: "Bulgarian Lev", c: "BGN", s: "лв", i: "bg", p: "suf" },
        { n: "Albanian Lek", c: "ALL", s: "L", i: "al", p: "suf" },
        { n: "Angolan Kwanza", c: "AOA", s: "Kz", i: "ao", p: "suf" },
        { n: "Afghan Afghani", c: "AFN", s: "Af", i: "af", p: "suf" },
        { n: "Azerbaijani Manat", c: "AZN", s: "₼", i: "az", p: "suf" },
        { n: "Kazakhstani Tenge", c: "KZT", s: "₸", i: "kz", p: "suf" },
        { n: "Moroccan Dirham", c: "MAD", s: "DH", i: "ma", p: "suf" },

        # CONTEXTUAL / REGION-SPECIFIC (suffix for clarity)
        { n: "Swiss Franc", c: "CHF", s: "Fr", i: "ch", p: "suf" },
        { n: "UAE Dirham", c: "AED", s: "د.إ", i: "ae", p: "suf" },
        { n: "Bahraini Dinar", c: "BHD", s: ".د.ب", i: "bh", p: "suf" },
        { n: "Jordanian Dinar", c: "JOD", s: "JD", i: "jo", p: "suf" },
        { n: "Kuwaiti Dinar", c: "KWD", s: "KD", i: "kw", p: "suf" },
        { n: "Omani Rial", c: "OMR", s: "RO", i: "om", p: "suf" },
        { n: "Qatari Rial", c: "QAR", s: "QR", i: "qa", p: "suf" },
        { n: "Saudi Riyal", c: "SAR", s: "SR", i: "sa", p: "suf" },
        { n: "Israeli Shekel", c: "ILS", s: "₪", i: "il", p: "suf" },
        { n: "Lebanese Pound", c: "LBP", s: "L£", i: "lb", p: "suf" },
        { n: "Pakistan Rupee", c: "PKR", s: "Rs", i: "pk", p: "suf" },
        { n: "Bangladeshi Taka", c: "BDT", s: "৳", i: "bd", p: "suf" },
        { n: "Armenian Dram", c: "AMD", s: "֏", i: "am", p: "suf" }
      ]
    end
    def format_money_ruby(amount, profile, currency_code = nil)
      code = currency_code.presence || profile.currency.presence || "USD"
      currency = currencies_data.find { |c| c[:c] == code }
      sym = currency ? currency[:s] : "$"
      pos = currency ? currency[:p] : "pre"
      amt = (amount || 0).to_f.round(2)
      sign = amt < 0 ? "-" : ""
      val = "%.2f" % amt.abs
      pos == "suf" ? "#{sign}#{val} #{sym}" : "#{sign}#{sym}#{val}"
    end

    def clean_num(number)
      return "0" if number.blank? || number.to_f == 0
      val = number.to_f.round(2)
      (val % 1 == 0) ? val.to_i.to_s : val.to_s
    end
end
