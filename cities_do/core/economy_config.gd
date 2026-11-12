extends RefCounted
## Confirmed economy rules. Construction/upkeep and taxes remain proposed; trade rates live in utility configs.
const CURRENCY_CODE := "doth"
const CURRENCY_SYMBOL := "\uFFFC" # Internal image slot, not a displayed currency glyph.
const CURRENCY_NAME_KO := "도쓰"
const DEFAULT_DIFFICULTY := "normal"
const NORMAL_STARTING_FUNDS := 50000

static func format_number(amount: int) -> String:
	var digits := str(absi(amount))
	var formatted := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length()-i)%3 == 0: formatted += ","
		formatted += digits[i]
	return ("−" if amount < 0 else "")+formatted

static func format_amount(amount: int) -> String:
	return format_number(amount)+" "+CURRENCY_SYMBOL

static func format_fraction(amount: float,decimals: int=6,signed: bool=false) -> String:
	var pieces: PackedStringArray=(("%."+str(decimals)+"f") % absf(amount)).split(".")
	var result:=format_number(int(pieces[0]))
	if pieces.size()>1:result+="."+pieces[1]
	return ("−" if amount<0 else ("+" if signed else ""))+result+" "+CURRENCY_SYMBOL
