Red []
GIF: context [
	version:
	left:
	top:
	width:
	height:
	color-table-exists?:
	color-depth:
	sorted?:
	color-table-size:
	background-color-index: 
	pixel-aspect-ratio:
	local-color-table-exists?:
	local-color-table-size:
	local-interlaced?:
	local-sorted?:
	packed:
	block-size:
	LZW-minimum-code-size:
	clear-code:
	end-of-input:
	byte:
	colors:
	prev:
	code:
		none
	code-size: 0
	color-table: copy []
	local-color-table: copy []
	
	code-table: make map! 1000
	indices: copy []
	codes: copy [] 
	stream: copy "" 

	
	get-code: function [
		binary-string [string!] "Short string (<= 16) of 0s and 1s"
	][
		len: length? binary-string
		len: case [
			len <= 8   [8]
			len <= 16  [16]
		]
		to integer! debase/base pad/left/with binary-string len #"0" 2
	]
	
	get-value: func [
		code [integer!]
	][
		either code < clear-code [to-block code][select code-table code]
	]
	
	map-by-index: func [indices table /zero /into collector][
		base: pick [0 1] none? zero 
		either into [
			collect/into [foreach i indices [keep table/(i + base)]] collector
			collector
		][
			collect [foreach i indices [keep table/(i + base)]]
		]
	]
	
	LZW-decode: function [stream [string!] /extern code-size colors prev code indices stream codes code-table][
		count: 0
		collect/into [
			while [not empty? c: take/last/part stream code-size][
				count: count + 1
				keep code: get-code c 
				;probe reduce [prev code]
				case [
					code = clear-code  [
						code-size: LZW-minimum-code-size + 1 
						prev: none
						clear code-table 
						available: end-of-input + 1
					]
					code = end-of-input [
						;new-line/skip indices true 10 
						;probe indices 
						;probe codes = aim 
						colors: make binary! 3 * length? indices
						table: either local-color-table-exists? [local-color-table][color-table]
						map-by-index/zero/into indices table colors
						return true
					]
					true [
						;if error? err: try [
							either selected: get-value code [
								append indices selected
								if prev [
									k: first selected
									available: end-of-input + 1 + length? code-table
									new: append copy get-value prev k
									put code-table available new
									if 2 ** code-size - 1 = available [code-size: code-size + 1]
								]
							][
								found: "-"
								k: first selected: get-value prev
								append indices new: append copy selected k
								put code-table code new
								if 2 ** code-size - 1 = code [code-size: code-size + 1]
							]
							prev: code
						;][
						;	probe reduce [
						;		"found" found
						;		"count" count
						;		"len"   length? codes
						;		"prev"  prev
						;		"code"  code
						;		"k"     k
						;		"avail" available
						;		"sel"   selected
						;		"new"   new
						;		"err"   :err
						;	]
						;	halt
						;]
					]
				]
			]
		] codes
	]

	header-rule: [
		copy version ["GIF87a" | "GIF89a" | (print "Not a GIF!" return false)]
		copy width  2 skip (width:  to integer! reverse width)
		copy height 2 skip (height: to integer! reverse height)
		copy packed skip (
			packed: enbase/base packed 2
			color-table-exists?: packed/1 = #"1"
			color-depth: 1 + get-code copy/part at packed 2 3
			sorted?: packed/5 = #"1"
			color-table-size: get-code at packed 6
			color-table-size: 2 ** (color-table-size + 1)
		)
		set background-color-index skip 
		set pixel-aspect-ratio skip
		opt [if (pixel-aspect-ratio > 0) (
			pixel-aspect-ratio: (pixel-aspect-ratio + 15) / 64
		)]
	]
	
	color-table-rule: [
		if (color-table-exists?) [
			(clear color-table)
			color-table-size [
				copy color 3 skip 
				(append color-table color) ;to tuple! color)
			]
		] 
	]
	
	graphics-control-extention: [
		#{21F9} ; start graphics control extention
		set block-size skip ; Is this always 4?
		skip   ; packed field
		2 skip ; delay time
		skip   ; transparent-color-index
		#{00}  ; terminator
	]
	
	image-rule: [
		image-descriptor
		opt local-color-table-rule
		image-data
	]
	
	image-descriptor: [
		#{2C} ; start image-descriptor
		copy left   2 skip (left:   to integer! reverse left)
		copy top    2 skip (top:    to integer! reverse top)
		copy width  2 skip (width:  to integer! reverse width)
		copy height 2 skip (height: to integer! reverse height)
		copy packed skip (
			packed: enbase/base packed 2
			local-color-table-exists?: packed/1 = #"1"
			local-interlaced?:         packed/2 = #"1"
			local-sorted?:             packed/3 = #"1"
			local-color-table-size: get-code at packed 6
		)
	]
	
	local-color-table-rule: [
		if (local-color-table-exists?) [
			(clear local-color-table)
			local-color-table-size [
				copy color 3 skip 
				(append local-color-table color) ;to tuple! color)
			]
		] 		
	]
	
	image-data: [
		set LZW-minimum-code-size skip
		(
			clear-code: 2 ** LZW-minimum-code-size
			end-of-input: clear-code + 1
			code-size: LZW-minimum-code-size + 1
			;probe reduce ["LZW-min" LZW-minimum-code-size "CC" clear-code "EOI" end-of-input "CS" code-size]
			clear indices
			clear codes
			clear stream
		)
		some [
			set block-size skip ;(probe reduce ["BS" block-size])
			[if (block-size > 0) block-size [
					copy byte skip 
					(insert stream enbase/base byte 2) 
				]
			| (LZW-decode stream) break]
			
		]
	]

	plain-text-extention: [
		#{2101} ; start plain text extention
		set block-size skip
		block-size skip
		some [
			set bloc-size skip
			[if (block-size > 0) block-size skip | break]
		]
	]
	
	application-extention: [
		#{21FF} ; start application extention
		set block-size skip
		block-size skip
		some [
			set block-size skip
			[if (block-size > 0) block-size skip | break]
		]
	]
	
	comment-extention: [
		#{21FE} ; start comment extention
		set block-size skip
		block-size skip
		some [
			set block-size skip
			[if (block-size > 0) block-size skip | break]
		]
	]
	
	decode: func [data [binary!] /local w h s p ctsz][
		parse data [
			header-rule
			opt color-table-rule
			some [s:
				opt graphics-control-extention
				[image-rule | plain-text-extention]
			|	application-extention
			|	comment-extention
			] 
			#{3B} ; trailer
		]
	]
]
comment [
test: #{4749463839610A000A00910000FFFFFFFF00000000FF00000021F90400000000002C000000000A000A000002168C2D99872A1CDC33A00275EC95FAA8DE608C04914C01003B}
GIF/decode test
]
