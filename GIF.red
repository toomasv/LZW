Red []
GIF: context [
	finished:
	show:
	version:
	left:
	top:
	width:
	height:
	size:
	color-table-exists?:
	color-depth:
	sorted?:
	color-table-size:
	background-color-index: 
	pixel-aspect-ratio:
	local-color-table-exists?:
	local-color-table-size:
	packed:
	block-size:
	LZW-minimum-code-size:
	clear-code:
	end-of-input:
	byte:
	colors:
	alpha:
	prev:
	code:
	netscape?:
	times:
	buffer-size:
	current:
	frame-id: 
		none
	
	code-size: 0
	color-table: copy []
	code-table: make map! 1000
	indices: copy []
	codes: copy [] 
	stream: copy ""
	frames: copy []

	frame: object [
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
		alpha:
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
	
	map-by-index: func [indices table /zero /into collector /transparent alpha-channel][
		base: pick [0 1] none? zero 
		either into [
			collect/into [
				foreach i indices [
					keep table/(i + base) 
					if transparent [
						append alpha-channel pick [#{FF} #{00}] i = current/transparent-index
					]
				]
			] collector
			collector
		][
			collect [foreach i indices [keep table/(i + base)]]
		]
	]
	
	LZW-decode: function [stream [string!] /extern code-size colors alpha prev code indices stream codes code-table][
		count: line: 0
		collect/into [
			while [not empty? c: take/last/part stream code-size][
				if error? err: try [
					count: count + 1
					;if count % current/size/x = 1 [print line: line + 1]
					keep code: get-code copy c 
					;probe reduce [code prev code-size c]
					case [
						code = clear-code  [
							code-size: LZW-minimum-code-size + 1
							available: end-of-input + 1
							prev: none
							clear code-table 
							;probe reduce ["====" code prev available code-size c]
						]
						code = end-of-input [
							;new-line/skip indices true 10 
							;probe indices 
							;probe codes = aim 
							colors: make binary! 3 * length? indices
							table: either local-color-table-exists? [current/color-table][color-table]
							either current/transparent? [
								alpha: make binary! length? indices
								map-by-index/zero/into/transparent indices table colors alpha
								;probe alpha
							][
								map-by-index/zero/into indices table colors
							]
							return true
						]
						true [
							either selected: get-value code [
								;prin 
								found: "+"
								append indices selected
								if prev [
									k: first selected
									available: end-of-input + 1 + length? code-table
									new: append copy get-value prev k
									put code-table available new
									if all [2 ** code-size - 1 = available available < 4095] [
										code-size: code-size + 1
										;prin "++++ "
										;probe reduce [code prev available code-size c new]
									]
								]
							][
								;prin 
								found: "-"
								unless prev [probe reduce ["???? " frame-id code prev available code-size c] prev: 1]
								k: first selected: get-value prev
								append indices new: append copy selected k
								put code-table code new
								if all [2 ** code-size - 1 = code code < 4095] [
									code-size: code-size + 1
								;	prin "++++ "
								;	probe reduce [code prev available code-size c new]
								]
							]
							prev: code
						]
					]
				][
					probe reduce [
						"found" found
						"count" count
						"len"   length? codes
						"prev"  prev
						"code"  code
						"k"     k
						"avail" available
						"sel"   selected
						"new"   new
						"c"     c
						"err"   :err
					]
					halt
				]
			]
		] codes
		false
	]

	; RULES
	
	header-rule: [
		copy version ["GIF87a" | "GIF89a" | (print "Not a GIF!" return false)]
	]

	logical-screen-descriptor: [ ; Exactly 7 bytes
		copy width  2 skip (width:  to integer! reverse width) ;1-2
		copy height 2 skip (height: to integer! reverse height ;3-4
		                    size:   as-pair width height)
		copy packed skip (                                     ;5
			packed: enbase/base packed 2
			color-table-exists?: packed/1 = #"1"
			color-depth: 1 + get-code copy/part at packed 2 3
			sorted?: packed/5 = #"1"
			color-table-size: get-code at copy packed 6
			if color-table-exists? [
				color-table-size: 2 ** (color-table-size + 1)
			]
		)
		set background-color-index skip                        ;6
		set pixel-aspect-ratio skip                            ;7
		opt [if (pixel-aspect-ratio > 0) (
			pixel-aspect-ratio: (pixel-aspect-ratio + 15) / 64
		)]
		(if show [
			prin "logical-screen-descriptor: " 
			probe new-line/skip reduce [
				"packed:"                 copy packed
				"color-table-exists?:"    color-table-exists? 
				"color-depth:"            color-depth 
				"sorted?:"                sorted? 
				"color-table-size:"       color-table-size
				"background-color-index:" background-color-index
				"pixel-aspect-ratio:"     pixel-aspect-ratio
			] true 2
		])
	]
	
	color-table-rule: [
		if (color-table-exists?) [
			(clear color-table)
			color-table-size [
				copy color 3 skip 
				(append color-table color) ;to tuple! color)
			]
			(if show [probe reduce ["color-table:" color-table]])
		] 
	]
	
	graphic-control-extension: [
		#{21F9} ; start graphic control extension
		(current: make frame [])
		set block-size skip ; Always 4
		copy packed skip (
			packed: enbase/base packed 2
			current/disposal:       get-code copy/part at packed 4 3
			current/user-input?:    packed/7 = #"1"
			current/transparent?:   packed/8 = #"1"
		)
		copy delay 2 skip (current/delay: to-integer reverse delay)
		set transparent-index skip (current/transparent-index: transparent-index) 
		#{00}  ; terminator
		(if show [
			prin "graphic-control-extension: " 
			probe new-line/skip reduce [
				"packed:"                    packed
				"current/disposal:"          current/disposal
				"current/user-input?:"       current/user-input?
				"current/transparent?:"      current/transparent?
				"current/delay:"             current/delay
				"current/transparent-index:" current/transparent-index
			] true 2
		]) ;s: (probe copy/part s 14)
	]
	
	image-rule: [
		image-descriptor
		opt local-color-table-rule
		image-data
	]
	
	image-descriptor: [
		#{2C} ; start image-descriptor
		(frame-id: frame-id + 1); if frame-id = 5 [halt])
		(unless current [current: make frame []])
		copy left   2 skip (left:   to integer! reverse left)
		copy top    2 skip (top:    to integer! reverse top 
			                current/pos: as-pair left top)
		copy width  2 skip (width:  to integer! reverse width)
		copy height 2 skip (height: to integer! reverse height 
			                current/size: as-pair width height)
		copy packed skip (
			packed: enbase/base packed 2
			local-color-table-exists?: packed/1 = #"1"
			current/interlaced?:       packed/2 = #"1"
			current/sorted?:           packed/3 = #"1"
			;4-5 reserved
			local-color-table-size:    get-code copy at packed 6
			if local-color-table-exists? [
				local-color-table-size: 2 ** (local-color-table-size + 1)
			]
		)
		(if show [
			prin "image-descriptor: " 
			probe new-line/skip reduce [
				"current/pos:"               current/pos
				"current/size:"              current/size
				"packed:"                    packed
				"local-color-table-exists?:" local-color-table-exists?
				"current/interlaced?:"       current/interlaced?
				"current/sorted?:"           current/sorted?
				"local-color-table-size:"    local-color-table-size
			] true 2
		])
	]
	
	local-color-table-rule: [
		if (local-color-table-exists?) [
			(current/color-table: copy [])
			local-color-table-size [
				copy color 3 skip 
				(append current/color-table color) ;to tuple! color)
			]
			(if show [probe reduce ["current/color-table (size):" length? current/color-table]])
		] 		
	]
	
	image-data: [
		set LZW-minimum-code-size skip
		(
			clear-code:   2 ** LZW-minimum-code-size
			end-of-input: clear-code + 1
			code-size:    LZW-minimum-code-size + 1
			if show [
				prin "image-data: "
				probe new-line/skip reduce [
					"LZW-minimum-code-size:" LZW-minimum-code-size 
					"clear-code:"            clear-code 
					"end-of-input:"          end-of-input 
					"Code-size:"             code-size
				] true 2
			]
			clear indices
			clear codes
			clear stream
		)
		some [s:
			set block-size skip ;(print ["BS:" block-size copy/part s 1] bs: 0);(probe reduce ["BS" block-size])
			[if (block-size > 0) block-size [
					copy byte skip 
					(append stream bt: reverse enbase/base byte 2
					;bs: bs + 1
					;if bs > (block-size - 5) [print [bs bt get-code copy bt]]
					) 
				]
			| (LZW-decode stream: reverse stream) break]
		](
			current/colors: copy colors
			if current/transparent? [current/alpha: copy alpha]
			append frames current 
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
		copy app block-size skip (netscape?: "NETSCAPE2.0" = to string! app); alt "ANIMEXTS1.0"
		;see http://www.vurdalakov.net/misc/gif/animexts-looping-application-extension
		some [
			set block-size skip ; Probably 3 (if animated) or 0
			[
				if (block-size > 0) 
					[
						#{01} ; Looping identification
						copy times 2 skip (
							times: to integer! reverse times
						);block-size skip 
					|	#{02} ; Buffer size identification
						copy buffer-size 2 skip (
							buffer-size: to integer! reverse buffer-size
						)
					]
			|	break
			]
		]
		(if show [
			prin "application-extension: " 
			probe new-line/skip reduce [
				"netscape?:" netscape?
				"times:"     times
			] true 2
		])
	]

	superfluous-application-extension: [
		#{21FF} ; start application extension
		set block-size skip
		copy app block-size skip ; Application name, eg. Adobe's "XMP DataXMP"
		; see https://archimedespalimpsest.net/Documents/External/XMP/XMPSpecificationPart3.pdf
		s: some [
			set block-size skip 
			[
				if (block-size > 0) block-size skip 
			|	e: (probe xmp: copy/part s e) break
			]
		]
		(if show [
			print "superfluous application-extension!" 
		])
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
		(finished: false)
		header-rule
		logical-screen-descriptor
		opt color-table-rule
		some [
			;opt 
			graphic-control-extension              ;This should be together with next, but there are some sloppy gifs
		|	[image-rule | plain-text-extension]
		|	application-extension any superfluous-application-extension
		|	comment-extension
		] 
		#{3B} (finished: yes) ; trailer
	]
	
	decode: func [data [binary! file! url!] /show][
		if find [url! file!] type?/word data [
			either %.gif = suffix? data [
				data: read/binary data
			][print "Not a GIF!" return false]
		]
		clear frames
		frame-id: 0
		self/show: show
		parse data main-rule
		finished
	]
	
	view: function [/all /extern lay][
		either system/words/all [1 < len: length? frames  netscape?] [
			if all [w: 0]
			pane: collect [
				if color-table-exists? [
					set 'bg make image! reduce [size to-tuple color-table/(background-color-index + 1)]
					either all [
						keep reduce ['panel size [origin 0x0 at 0x0 image bg]]
					][
						keep [at 0x0 image bg]
						;keep 'at keep 0x0
						;keep 'image keep 'bg
					]
				]
				repeat i len [
					frame: frames/:i
					image: make image! reduce either frame/transparent? [
						[frame/size frame/colors frame/alpha]
					][
						[frame/size frame/colors]
					]
					set img: to-word rejoin ["img" i] image
					either all [
						keep reduce ['panel size reduce ['origin 0x0 'at frame/pos 'image img]]
						if (w: w + 1) % 4 = 0 [keep 'return]
					][
						;unless all [keep 'at keep frame/pos]
						;if system/words/all [all (w: w + 1) % 4 = 0][keep 'return]
						;keep 'image keep img 
						;unless all [either i > 1 [keep 'hidden][]]
						keep 'at keep frame/pos
						keep 'image keep img 
						either i > 1 [keep 'hidden][]
					]
				]
			]
			;insert pane either all [[origin 1x1]][[origin 0x0]]
			insert pane [origin 0x0]
			either all [
				set 'lay layout compose/only [
					backdrop black
					panel (system/view/screens/1/size - 200)
						on-down [xy: event/offset 'stop]
						all-over on-over [if event/down? [
							df: event/offset - xy foreach fc face/pane [fc/offset: fc/offset + df]
							xy: event/offset
						] 'stop] 
						(pane)
				]
			][
				rate: 100 / frames/1/delay
				rate: either rate < 1 [to-time 1 / rate][to-integer rate]
				append/only timer: compose [switch tick % (len)] collect [
					repeat i len [
						keep j: i - 1
						either zero? j [
							either color-table-exists? [ ; we have background-image
								blk: copy [foreach img next next face/pane [img/visible?: no] tick: 1]
								if frames/1/disposal = 2 [append blk [face/pane/2/visible?: yes]]
								keep/only blk
							][
								keep/only [foreach img next face/pane [img/visible?: no] tick: 1]
							]
						][
							blk: reduce [to-set-path compose [face pane (i) visible?] 'yes]
							if frames/:j/disposal = 2 [
								insert blk reduce [to-set-path compose [face pane (j) visible?] 'no]
							]
							keep/only blk
						]
					]
				]
				append timer [tick: tick + 1]
				set 'lay layout compose/only [panel (size) (pane) rate (rate) on-time (timer) do [tick: 0]]
			]
			system/words/view lay
		][
			img: make image! reduce [frames/1/size frames/1/colors]
			system/words/view [image img]
		]
	]
]

comment [
	do %GIF.red
	GIF/decode %dancing.gif ; %sample_1.gif ; sample_1_enlarged.gif ; gif_file_stream.gif ; 
	GIF/view
]
