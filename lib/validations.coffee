@num =
	greater_than:
		fn: (a,b)   -> a > b
		msg: (a, b) -> "#{a} must be greater than #{b}."
	greater_than_or_equal_to:
		fn: (a,b)   -> a >= b
		msg: (a,b)  -> "#{a} must be greater than or equal to #{b}."
	equal_to:
		fn: (a,b) -> a is b
		msg: (a,b) -> "#{a} must be equal to #{b}."
	less_than:
		fn: (a,b) -> a < b
		msg: (a,b) -> "#{a} must be less than #{b}."
	less_than_or_equal_to:
		fn: (a,b) -> a <= b
		msg: (a,b) -> "#{a} must be less than or equal to #{b}."
	odd:
		fn: (a) -> !!(a % 2)
		msg: (a) -> "#{a} must be odd."
	even:
		fn: (a) -> !(a % 2)
		msg: (a) -> "#{a} must be even."
	only_integer:
		fn: (n) -> typeof n is 'number' and parseFloat(n) is parseInt(n,10) and not isNaN(n) and isFinite(n)
		msg: (n) -> "#{n} must be an integer."

@size =
	minimum:
		fn: (len, min) -> len >= min
		msg: (field, len, min) -> "'#{field}' length is #{len}. Must be bigger than #{min}."
	maximum:
		fn: (len, max) -> len <= max
		msg: (field, len, max) -> "'#{field}' length is #{len}. Must be smaller than #{max}."
	in:
		fn: (len, range) -> range[0] <= len <= range[1]
		msg: (field, len, range) -> "'#{field}' length is #{len}. Must be between #{range[0]} and #{range[1]}."
	is:
		fn: (len1, len2) -> len1 is len2
		msg: (field, len1, len2) -> "'#{field}' length is #{len1}. Must be #{len2}."
