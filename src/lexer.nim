import algorithm, sequtils
import utils, position, token

## ### LEXER ### ##

type 
    CharConfigProc*[T: enum] = proc(l: var Lexer[T], c: char, k: T): void
    CharConfig*[T: enum] = tuple
        `char`: seq[char]
        `proc`: CharConfigProc[T]
        kind: T
    StringConfigProc*[T: enum] = proc(l: var Lexer[T], s: string, K: T): void
    StringConfig*[T: enum] = tuple
        `string`: string
        `proc`: StringConfigProc[T]
        kind: T
    Lexer*[T: enum] = object
        position*: Position
        source*: string
        tokens*: seq[Token[T]]
        current_string*: string
        charConfigs*: seq[CharConfig[T]]
        stringConfigs*: seq[StringConfig[T]]

# ### LEXER CONFIGS ### #

proc getCharConfig*[T: enum](`proc`: CharConfigProc[T], `char`: seq[char], kind: T): CharConfig[T] =
    ## Get char config for a procedure and a list of chars
    ## Usage:
    ## 
    ## ```
    ## var config = getCharConfig(handleSpace, @[' '])
    ## ```
    result.`char` = `char`
    result.`proc` = `proc`
    result.kind = kind

proc addCharConfig*[T: enum](l: var Lexer[T], `proc`: CharConfigProc[T], `char`: seq[char], kind: T = default(T)): void =
    ## Add char config to the lexer
    ## Usage:
    ## 
    ## ```
    ## addCharConfig(lexer, handleSpace, @[' '])
    ## ```
    l.charConfigs.add(getCharConfig(`proc`, `char`, kind))

proc getStringConfig*[T: enum](`proc`: StringConfigProc[T], `string`: string, kind: T): StringConfig[T] =
    ## Get string config for a procedure and a string
    ## Usage:
    ## 
    ## ```
    ## var config = getStringConfig(handleFunctionTypeAssign, "=>")
    ## ```
    result.`string` = `string`
    result.`proc` = `proc`
    result.kind = kind

proc addStringConfig*[T: enum](l: var Lexer[T], `proc`: StringConfigProc[T], `string`: string, kind: T = default(T)): void =
    ## Add string config to the lexer
    ## Usage:
    ## 
    ## ```
    ## addStringConfig(lexer, handleFunctionTypeAssign, "=>")
    ## ```
    l.stringConfigs.add(getStringConfig(`proc`, `string`, kind))


proc initLexer*[T: enum](s: string, charConfigs: seq[CharConfig[T]] = @[], stringConfigs: seq[StringConfig[T]] = @[]): Lexer[T] =
    ## Initialize a lexer
    ## 
    ## Args:
    ## - s: The source code
    ## - charConfigs: A list of char configs
    ## - stringConfigs: A list of string configs
    result.position = initPosition()
    result.source = s
    result.tokens = @[]
    result.current_string = ""
    result.charConfigs = charConfigs
    result.stringConfigs = stringConfigs

proc peek*(l: var Lexer): char =
    ## Peek the current char
    ## This is used to get the current char in the source code
    if l.position.index < l.source.len:
        return l.source[l.position.index]
    return '\0'

proc advance*(l: var Lexer): void =
    ## Advance the position
    ## This is used to advance the position in the source code
    ## When a char is processed, the position is advanced
    ## It also handles column and line numbers for the position
    if l.position.index < l.source.len:
        l.position.advance()
    if l.peek() == '\n':
        l.position.line += 1
        l.position.column = 0
    else:
        l.position.column += 1

proc addToken*[T: enum](
    l: var Lexer[T], 
    kind: T = default(T),
    value: string = ""
    ): void =
    ## Add a token to the tokens list of the lexer
    ## 
    ## Args:
    ## - l: The lexer
    ## - kind: The kind of the token
    ## - value: The value of the token
    ## 
    ## They are 4 cases to consider when adding a token
    ## 1. If no argument is passed, the current string is added as a identifier token
    ## 2. If a value is passed, the value and the current string are added as a identifier token
    ## 3. If a kind is passed, the current string is added as a token with the kind passed
    ## 4. If a kind and a value is passed, the value is added as a token with the kind and the current string is added as a identifier token
    if l.current_string.len > 0:
        var t : Token[T]
        t.kind = kind
        if value.len > 0:
            t.kind = default(T)
        t.value = l.current_string
        l.tokens.add(t)
        l.current_string = ""
    if value.len > 0:
        var t = Token[T]()
        t.kind = kind
        t.value = value
        l.tokens.add(t)
    
    

proc defaultHandleChar*(l: var Lexer, c: char): void =
    ## Function to handle char if no char config or string config is found
    ## 
    ## It adds the char to the current string
    l.current_string.add(c)

proc handleChar*[T: enum](l: var Lexer[T], c: char, `proc`: CharConfigProc[T], k: T = default(T)): void =
    ## Handle a char by calling the related proc and advancing the position
    `proc`(l, c, k)
    l.advance()

proc handleCharConfig*[T: enum](l: var Lexer[T], c: char): bool =
    ## Find the char config for the current char and call the related proc
    ## 
    ## Returns:
    ## - true if a char config is found and called
    ## - false if no char config is found
    
    # filter char configs that has the current char
    let charConfigs = l.charConfigs.filter(proc(a: CharConfig[T]): bool = c in a.`char`)
    # if there is more than one char config, raise an error
    if charConfigs.len > 1:
        raise newException(ValueError, "More than one char config found")
    # if there is no char config, return false
    if charConfigs.len == 0:
        return false
    # get the char config
    let config = charConfigs[0]
    # call the char config proc
    l.handleChar(c, config.`proc`, config.kind)
    return true

proc checkCharConfig*[T: enum](l: var Lexer[T]): void =
    ## Check if the char config is ok
    ## 
    ## Raises an error if more than one char config per char is found
    
    # create a list of all chars in the char configs
    var chars: seq[char] = @[]
    for config in l.charConfigs:
        chars.add(config.`char`)
    # create a list of all chars that are duplicated
    var duplicates: seq[char] = @[]
    for c in chars:
        if chars.count(c) > 1:
            duplicates.add(c)
    # if there are duplicates, raise an error
    if duplicates.len > 0:
        # remove duplicates
        duplicates = duplicates.removeDuplicates()
        raise newException(ValueError, "Duplicate char config found for chars: " & $duplicates)

proc handleStringConfig*[T: enum](l: var Lexer[T], c: char): bool =
    ## Find the string config for the current char and call the related proc
    ## 
    ## Returns:
    ## - true if a string config is found and called
    ## - false if no string config is found
    
    # filter the string configs which has teh fisrt char as the current char
    let stringConfigs = l.stringConfigs.filter(proc(a: StringConfig[T]): bool = a.`string`[0] == c)
    # iterate through the string configs
    for i in 0..stringConfigs.len-1:
        # get the string config
        let config = stringConfigs[i]
        # get the len of the string
        let len = config.`string`.len
        # check if the string is in the source code
        if l.position.index + len < l.source.len:
            # get the string from the source code
            let s = l.source[l.position.index..l.position.index + len-1]
            # check if the string is the same as the config string
            if $s == $config.`string`:
                # call the config proc
                config.`proc`(l, s, config.kind)
                # advance the position
                for j in 0..len-1:
                    l.advance()
                return true

proc checkStringConfig*[T: enum](l: var Lexer[T]): void =
    ## Check if the string config is ok
    ## 
    ## Raises an error if more than one string config per char is found
    
    # create a list of all strings in the string configs
    var strings: seq[string] = @[]
    for config in l.stringConfigs:
        strings.add(config.`string`)
    # create a list of all strings that are duplicated
    var duplicates: seq[string] = @[]
    for c in strings:
        if strings.count(c) > 1:
            duplicates.add(c)
    # if there are duplicates, raise an error
    if duplicates.len > 0:
        # remove duplicates
        duplicates = duplicates.removeDuplicates()
        raise newException(ValueError, "Duplicate string config found for strings: " & $duplicates)

proc lex*[T: enum](l: var Lexer[T]): void = 
    ## Lex the source code
    ## This is used to tokenize the source code depending on the provided char and string configs
    ## 
    ## It will prioritize the string configs over the char configs
    # check configs
    l.checkCharConfig()
    l.checkStringConfig()
    # Sort the char configs by length of char
    l.stringConfigs.sort(proc(a, b: StringConfig[T]): int = -cmp(a.`string`.len, b.`string`.len))
    while l.position.index < l.source.len:
        let c = l.peek()
        # find the char config
        if l.handleStringConfig(c):
            continue
        if l.handleCharConfig(c):
            continue
        else:
            l.defaultHandleChar(c)
            l.advance()
            continue