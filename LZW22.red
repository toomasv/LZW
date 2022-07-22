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

LZW22: context [
	limit: 256 ;Below this are chars, from this up - strings; may be increased if needed
	stringTable: make map! []
	codeTable: copy  []
	
    getCode: func [s [string! char!]][
        either single? s [to integer! s/1][select/case stringTable s]
    ]
    
    getString: func [code [integer!]][
        either code < limit [to char! code][stringTable/:code]
    ]
    
    top: function [str][
		cs: charset str
		repeat n l: 1 + length? cs [if cs/(i: l - n) [break]]
		i
	]
	
	pop: func [s][head clear back tail s]
	
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
        clear codeTable
        if limit [self/limit: limit]
        code: self/limit 
        old: copy/part string 1
        foreach new next string [
        	append old new
			unless find/case stringTable old [
        		put/case stringTable old code
				append codeTable getCode pop old
            	code: code + 1
            	append clear old new
        	]
        ]
        append codeTable getCode old
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
        outPut: to string! c
        foreach new next codes [
        	unless s: getString new [s: rejoin [getString old c]]
        	append outPut s
        	c: first to-string s
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
        codes: LZW22/Compress string
        prin "Codes  " probe codes
        result: LZW22/Decompress codes
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
	i: LZW22/top str
	t: dt [
		cod: LZW22/compress/size str i + 1
		str2: LZW22/decompress cod
	]
	print str = str2
	print third t
]
