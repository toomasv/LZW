Red [
	File: %LZW2.red
	Description: {Implements parse-based algorithm for LZW compression and decompression with extendable codes}
	Authors: "François Jouen and Toomas Vooglaid"
	Rights:  "Copyright (C) 2022 Red Foundation. All rights reserved."
    License: {
        Distributed under the Boost Software License, Version 1.0.
        See https://github.com/red/red/blob/master/BSL-License.txt
    }
    See: https://gitter.im/red/red/system?at=62d595d776cd751a2f3d7239
    Date: 19-July-2022
]
lzw-ctx: context [
    string-table: make map! []
    limit: 256    ;Below this are chars, from this up - strings; may be increased if needed
    get-code: func [w [string! char!]][
        either string? w [select/case string-table w][to-integer w]
    ]
    get-string: func [code [integer!]][
        either code > limit [string-table/:code][to-char code]
    ]

    set 'lzw-compress function [
		string [string!]
		/size  limit
	][
        if empty? string [return copy []]
        clear string-table
		if limit [self/limit: limit]
        code: self/limit 
        old: first string
        ending: [end keep (get-code old)]
        parse next string [
            collect some [
                set new skip (composed: rejoin [old new])
                [ if (find/case string-table composed) (old: composed)
                | keep (get-code old)
                  (
                    put/case string-table composed code 
                    code: code + 1 
                    old: new
                  )
                ]
                opt ending
            |   ending
            ]
        ]
    ]

    set 'lzw-decompress function [
		codes [block!]
		/size limit
	][
        if empty? codes [return copy ""]
        clear string-table
		if limit [self/limit: limit]
        code: self/limit 
        old: first codes
        rejoin parse next codes [
            collect [
                keep (c: get-string old) 
                some [
                    set new skip 
                    opt [if (not s: get-string new)(s: rejoin [get-string old c])]
                    keep (s)
                    (
                        c: first to-string s
                        string-table/:code: rejoin [get-string old c]
                        code: code + 1
                        old: new
                    )
                ]
            ]
        ]
    ]
]