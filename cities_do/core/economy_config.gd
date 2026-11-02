extends RefCounted
## Confirmed economy rules. Prices, taxes and trade rates remain unspecified.
const CURRENCY_CODE := "doth"
const CURRENCY_NAME_KO := "도쓰"
const DEFAULT_DIFFICULTY := "normal"
const NORMAL_STARTING_FUNDS := 50000

static func format_amount(amount: int) -> String:
	var digits := str(absi(amount))
	var formatted := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length()-i)%3 == 0: formatted += ","
		formatted += digits[i]
	return ("-" if amount < 0 else "")+formatted+" "+CURRENCY_CODE
