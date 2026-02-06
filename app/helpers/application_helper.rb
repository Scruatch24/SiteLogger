# app/helpers/application_helper.rb
module ApplicationHelper
    def currencies_data
      [
        # PREFIX currencies (symbol before number)
        { n: t("currencies.usd"), c: "USD", s: "$", i: "us", p: "pre" },
        { n: t("currencies.gbp"), c: "GBP", s: "£", i: "gb", p: "pre" },
        { n: t("currencies.jpy"), c: "JPY", s: "¥", i: "jp", p: "pre" },
        { n: t("currencies.aud"), c: "AUD", s: "A$", i: "au", p: "pre" },
        { n: t("currencies.cad"), c: "CAD", s: "C$", i: "ca", p: "pre" },
        { n: t("currencies.cny"), c: "CNY", s: "¥", i: "cn", p: "pre" },
        { n: t("currencies.inr"), c: "INR", s: "₹", i: "in", p: "pre" },
        { n: t("currencies.brl"), c: "BRL", s: "R$", i: "br", p: "pre" },
        { n: t("currencies.mxn"), c: "MXN", s: "$", i: "mx", p: "pre" },
        { n: t("currencies.ars"), c: "ARS", s: "$", i: "ar", p: "pre" },
        { n: t("currencies.clp"), c: "CLP", s: "$", i: "cl", p: "pre" },
        { n: t("currencies.cop"), c: "COP", s: "$", i: "co", p: "pre" },
        { n: t("currencies.hkd"), c: "HKD", s: "HK$", i: "hk", p: "pre" },
        { n: t("currencies.egp"), c: "EGP", s: "E£", i: "eg", p: "pre" },
        { n: t("currencies.nzd"), c: "NZD", s: "NZ$", i: "nz", p: "pre" },
        { n: t("currencies.sgd"), c: "SGD", s: "S$", i: "sg", p: "pre" },
        { n: t("currencies.thb"), c: "THB", s: "฿", i: "th", p: "pre" },
        { n: t("currencies.twd"), c: "TWD", s: "NT$", i: "tw", p: "pre" },
        { n: t("currencies.php"), c: "PHP", s: "₱", i: "ph", p: "pre" },
        { n: t("currencies.zar"), c: "ZAR", s: "R", i: "za", p: "pre" },
        { n: t("currencies.ngn"), c: "NGN", s: "₦", i: "ng", p: "pre" },
        { n: t("currencies.kes"), c: "KES", s: "KSh", i: "ke", p: "pre" },
        { n: t("currencies.myr"), c: "MYR", s: "RM", i: "my", p: "pre" },
        { n: t("currencies.idr"), c: "IDR", s: "Rp", i: "id", p: "pre" },

        # SUFFIX currencies (symbol after number)
        { n: t("currencies.eur"), c: "EUR", s: "€", i: "eu", p: "suf" },
        { n: t("currencies.gel"), c: "GEL", s: "₾", i: "ge", p: "suf" },
        { n: t("currencies.try"), c: "TRY", s: "₺", i: "tr", p: "suf" },
        { n: t("currencies.sek"), c: "SEK", s: "kr", i: "se", p: "suf" },
        { n: t("currencies.dkk"), c: "DKK", s: "kr", i: "dk", p: "suf" },
        { n: t("currencies.nok"), c: "NOK", s: "kr", i: "no", p: "suf" },
        { n: t("currencies.isk"), c: "ISK", s: "kr", i: "is", p: "suf" },
        { n: t("currencies.pln"), c: "PLN", s: "zł", i: "pl", p: "suf" },
        { n: t("currencies.huf"), c: "HUF", s: "Ft", i: "hu", p: "suf" },
        { n: t("currencies.czk"), c: "CZK", s: "Kč", i: "cz", p: "suf" },
        { n: t("currencies.ron"), c: "RON", s: "lei", i: "ro", p: "suf" },
        { n: t("currencies.vnd"), c: "VND", s: "₫", i: "vn", p: "suf" },
        { n: t("currencies.uah"), c: "UAH", s: "₴", i: "ua", p: "suf" },
        { n: t("currencies.bgn"), c: "BGN", s: "лв", i: "bg", p: "suf" },
        { n: t("currencies.all"), c: "ALL", s: "L", i: "al", p: "suf" },
        { n: t("currencies.aoa"), c: "AOA", s: "Kz", i: "ao", p: "suf" },
        { n: t("currencies.afn"), c: "AFN", s: "Af", i: "af", p: "suf" },
        { n: t("currencies.azn"), c: "AZN", s: "₼", i: "az", p: "suf" },
        { n: t("currencies.kzt"), c: "KZT", s: "₸", i: "kz", p: "suf" },
        { n: t("currencies.mad"), c: "MAD", s: "DH", i: "ma", p: "suf" },

        # CONTEXTUAL / REGION-SPECIFIC (suffix for clarity)
        { n: t("currencies.chf"), c: "CHF", s: "Fr", i: "ch", p: "suf" },
        { n: t("currencies.aed"), c: "AED", s: "د.إ", i: "ae", p: "suf" },
        { n: t("currencies.bhd"), c: "BHD", s: ".د.ب", i: "bh", p: "suf" },
        { n: t("currencies.jod"), c: "JOD", s: "JD", i: "jo", p: "suf" },
        { n: t("currencies.kwd"), c: "KWD", s: "KD", i: "kw", p: "suf" },
        { n: t("currencies.omr"), c: "OMR", s: "RO", i: "om", p: "suf" },
        { n: t("currencies.qar"), c: "QAR", s: "QR", i: "qa", p: "suf" },
        { n: t("currencies.sar"), c: "SAR", s: "SR", i: "sa", p: "suf" },
        { n: t("currencies.ils"), c: "ILS", s: "₪", i: "il", p: "suf" },
        { n: t("currencies.lbp"), c: "LBP", s: "L£", i: "lb", p: "suf" },
        { n: t("currencies.pkr"), c: "PKR", s: "Rs", i: "pk", p: "suf" },
        { n: t("currencies.bdt"), c: "BDT", s: "৳", i: "bd", p: "suf" },
        { n: t("currencies.amd"), c: "AMD", s: "֏", i: "am", p: "suf" }
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

    def category_icon_map
      {
        "briefcase" => '<path fill-rule="evenodd" d="M6 3.75A2.75 2.75 0 0 1 8.75 1h2.5A2.75 2.75 0 0 1 14 3.75v.443c.572.055 1.14.122 1.706.2C17.053 4.582 18 5.75 18 7.07v3.469c0 1.126-.694 2.191-1.83 2.54-1.952.599-4.024.921-6.17.921s-4.219-.322-6.17-.921C2.694 12.73 2 11.665 2 10.539V7.07c0-1.321.947-2.489 2.294-2.676A41.047 41.047 0 0 1 6 4.193V3.75Zm6.5 0v.325a41.622 41.622 0 0 0-5 0V3.75c0-.69.56-1.25 1.25-1.25h2.5c.69 0 1.25.56 1.25 1.25ZM10 10a1 1 0 0 0-1 1v.01a1 1 0 0 0 1 1h.01a1 1 0 0 0 1-1V11a1 1 0 0 0-1-1H10Z" clip-rule="evenodd" /><path d="M3 15.055v-.684c.126.053.255.1.39.142 2.092.642 4.313.987 6.61.987 2.297 0 4.518-.345 6.61-.987.135-.041.264-.089.39-.142v.684c0 1.347-.985 2.53-2.363 2.686a41.454 41.454 0 0 1-9.274 0C3.985 17.585 3 16.402 3 15.055Z" />',
        "home" => '<path fill-rule="evenodd" d="M9.293 2.293a1 1 0 0 1 1.414 0l7 7A1 1 0 0 1 17 11h-1v6a1 1 0 0 1-1 1h-2a1 1 0 0 1-1-1v-3a1 1 0 0 0-1-1H9a1 1 0 0 0-1 1v3a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-6H3a1 1 0 0 1-.707-1.707l7-7Z" clip-rule="evenodd" />',
        "star" => '<path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />',
        "heart" => '<path fill-rule="evenodd" d="M3.172 5.172a4 4 0 015.656 0L10 6.343l1.172-1.171a4 4 0 115.656 5.656L10 17.657l-6.828-6.829a4 4 0 010-5.656z" clip-rule="evenodd" />',
        "shopping-cart" => '<path d="M3 1a1 1 0 000 2h1.22l.305 1.222a.997.997 0 00.01.042l1.358 5.43-.893.892C3.74 11.846 4.632 14 6.414 14H15a1 1 0 000-2H6.414l1-1H14a1 1 0 00.894-.553l3-6A1 1 0 0017 3H6.28l-.31-1.243A1 1 0 005 1H3zM16 16.5a1.5 1.5 0 11-3 0 1.5 1.5 0 013 0zM6.5 18a1.5 1.5 0 100-3 1.5 1.5 0 000 3z" />',
        "tag" => '<path fill-rule="evenodd" d="M17.707 9.293a1 1 0 010 1.414l-7 7a1 1 0 01-1.414 0l-7-7A.997.997 0 012 10V5a3 3 0 013-3h5c.256 0 .512.098.707.293l7 7zM5 6a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd" />',
        "user" => '<path fill-rule="evenodd" d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z" clip-rule="evenodd" />',
        "camera" => '<path fill-rule="evenodd" d="M4 5a2 2 0 00-2 2v8a2 2 0 002 2h12a2 2 0 002-2V7a2 2 0 00-2-2h-1.586a1 1 0 01-.707-.293l-1.121-1.121A2 2 0 0011.172 3H8.828a2 2 0 00-1.414.586L6.293 4.707A1 1 0 015.586 5H4zm6 9a3 3 0 100-6 3 3 0 000 6z" clip-rule="evenodd" />',
        "globe" => '<path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM4.332 8.027a6.012 6.012 0 011.912-2.706C6.512 5.73 6.974 6 7.5 6A1.5 1.5 0 019 7.5V8a2 2 0 004 0 2 2 0 014 0 1.499 1.499 0 01.8 2.315c-.322.692-.77 1.341-1.218 1.956L14 14v1a1 1 0 01-1 1h-1a1 1 0 01-1-1v-2h-1a1 1 0 01-1-1v-1a1 1 0 00-1-1H7a1 1 0 01-1-1v-1a1 1 0 00-1-1H4.332z" clip-rule="evenodd" />',
        "lightning" => '<path d="M11.983 1.907a.75.75 0 0 0-1.292-.657l-8.5 9.5A.75.75 0 0 0 2.75 12h6.572l-1.305 6.093a.75.75 0 0 0 1.292.657l8.5-9.5A.75.75 0 0 0 17.25 8h-6.572l1.305-6.093Z" />'
      }
    end
end
