#!/usr/local/bin/red
Red [
	Title:    "Red Language: LZW string compression and decompression "
	Authors:  "François Jouen and Toomas Vooglaid"
	File: 	  %LZW2.red
	Tabs:	  4
	Rights:  "Copyright (C) 2022 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

;--The Lempel-Ziv-Welch (LZW) algorithm provides loss-less data compression.
;--This code for strings is case-sensitive

LZW21: context [
	limit: 256 ;Below this are chars, from this up - strings; may be increased if needed
	stringTable: make map! []
	
    getCode: func [w [string! char!]][
        either string? w [select/case stringTable w][to-integer w]
    ]
    
    getString: func [code [integer!]][
        either code >= limit [stringTable/:code][to-char code]
    ]
    
    top: function [str][
		cs: charset str
		repeat n l: 1 + length? cs [if cs/(i: l - n) [break]]
		i
	]
	
	mismatch: function [s1 s2][
		s3: s1
		forall s1 [if s1/1 <> s2/(i: index? s1) [break]]
		s1: s3
		i
	]
    
    Compress: function [
    	string [string!]
    	/size limit 
    ][
    	if empty? string [return copy []]
        clear StringTable 
        codeTable: copy []
        if limit [self/limit: limit]
        code: self/limit 
        old: string/1
        foreach new next string [
        	composed: rejoin [old new]
			either find/case stringTable composed [old: composed][
				append codeTable getCode old
        		put/case stringTable composed code
            	code: code + 1
            	old: new
        	]
        ]
        if old [append codeTable getCode old]
        codeTable
    ];--end of compress
    
    Decompress: function [
    "Decompress a list of codes to a string"
    	codes    [block!]
    	/size limit    
	][  
		if empty? codes [return copy ""]
        clear stringTable
        if limit [self/limit: limit]
        code: self/limit 
        c: to-char old: first codes
        outPut: to string! getString old
        foreach new next codes [
        	unless s: getString new [s: rejoin [getString old c]]
        	append outPut s
        	c: first to string! s
            stringTable/:code: rejoin [getString old c]
            code: code + 1
            old: new
        ]
        outPut
	];--end of Decompress
];--end of context

;-*************************Tests*********************************
comment [
    lzw-test: function [string [string!]][
        print "--------------"
        prin "String "  probe string
        codes: LZW21/Compress string
        prin "Codes  " probe codes
        result: LZW21/Decompress codes
        prin "Result "  probe result
    ]
    lzw-test "WyS*WyGWYS*WySWYSG"
    lzw-test "ABRacADabRaAAa"
    lzw-test "^/" 
    lzw-test "AAA"
    lzw-test ""
]

comment [
	str: read https://github.com/red/docs/blob/master/en/parse.adoc
	i: LZW21/top str
	t: dt [
		cod: LZW21/compress/size str i + 1
		str2: LZW21/decompress cod
	]
	print str = str2
	print third t
]


