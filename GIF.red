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
	;local-interlaced?:
	;local-sorted?:
	packed:
	block-size:
	LZW-minimum-code-size:
	clear-code:
	end-of-input:
	byte:
	colors:
	prev:
	code:
	netscape?:
	times:
		none
	code-size: 0
	color-table: copy []
	
	code-table: make map! 1000
	indices: copy []
	codes: copy [] 
	stream: copy ""
	images: copy []

	image: object [
		disposal:
		user-input?:
		transparent?:
		delay:
		transparent-index:
		pos:
		size:
		interlaced?:
		sorted?:
		color-table:
		colors:
			none
	]
		
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
								;found: "+"
								append indices selected
								if prev [
									k: first selected
									available: end-of-input + 1 + length? code-table
									new: append copy get-value prev k
									put code-table available new
									if 2 ** code-size - 1 = available [code-size: code-size + 1]
								]
							][
								;found: "-"
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
		copy height 2 skip (height: to integer! reverse height size: as-pair width height)
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
	
	graphic-control-extension: [
		#{21F9} ; start graphic control extension
		(current: make image [])
		set block-size skip ; Always 4
		copy graphic-packed skip (
			graphic-packed: enbase/base graphic-packed 2
			current/disposal:       get-code copy/part at graphic-packed 4 3
			current/user-input?:    graphic-packed/7 = #"1"
			current/transparent?:   graphic-packed/8 = #"1"
		)
		copy delay 2 skip (current/delay: to-integer reverse delay)
		set transparent-index skip (current/transparent-index: transparent-index) 
		#{00}  ; terminator
	]
	
	image-rule: [
		image-descriptor
		opt local-color-table-rule
		image-data
	]
	
	image-descriptor: [
		#{2C} ; start image-descriptor
		(unless current [current: make image []])
		copy left   2 skip (left:   to integer! reverse left)
		copy top    2 skip (top:    to integer! reverse top 
			                current/pos: as-pair left top)
		copy width  2 skip (width:  to integer! reverse width)
		copy height 2 skip (height: to integer! reverse height 
			                current/size: as-pair width height)
		copy packed skip (
			packed: enbase/base packed 2
			local-color-table-exists?: packed/1 = #"1"
			current/interlaced?:         packed/2 = #"1"
			current/sorted?:             packed/3 = #"1"
			local-color-table-size:    get-code at packed 6
		)
	]
	
	local-color-table-rule: [
		if (local-color-table-exists?) [
			(current/color-table: copy [])
			local-color-table-size [
				copy color 3 skip 
				(append current/color-table color) ;to tuple! color)
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
		](
			current/colors: copy colors
			append images current 
			current: none
		)
	]

	plain-text-extension: [
		#{2101} ; start plain text extension
		set block-size skip
		block-size skip
		some [
			set bloc-size skip
			[if (block-size > 0) block-size skip | break]
		]
	]
	
	application-extension: [
		#{21FF} ; start application extension
		set block-size skip
		copy app block-size skip (netscape?: "NETSCAPE2.0" = to string! app)
		some [
			set block-size skip ; Probably 3 (if animated) or 0
			[
				if (block-size > 0) 
					#{01} ; Always
					copy times 2 skip (
						times: to integer! reverse times
					);block-size skip 
			|	break
			]
		]
	]
	
	comment-extension: [
		#{21FE} ; start comment extension
		set block-size skip
		block-size skip
		some [
			set block-size skip
			[if (block-size > 0) block-size skip | break]
		]
	]
	
	main-rule: [
		header-rule
		opt color-table-rule
		some [
			opt graphic-control-extension
			[image-rule | plain-text-extension]
		|	application-extension
		|	comment-extension
		] 
		#{3B} ; trailer
	]
	
	decode: func [data [binary! file!]][
		if file? data [
			either %.gif = suffix? data [
				data: read/binary data
			][print "Not a GIF!" return false]
		]
		(clear images)
		parse data main-rule
	]
	
	view: function [][
		img: make image! reduce [as-pair width height green]
		img/rgb: colors
		system/words/view [image img]
	]
]

comment [
	do %GIF.red
	GIF/decode %dancing.gif ; %sample_1.gif ; sample_1_enlarged.gif ; gif_file_stream.gif ; 
	GIF/view
]
