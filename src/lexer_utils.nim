import lexer

proc handleSpace*[T: enum](l: var Lexer[T], c: char, kind: T = default(T)): void =
    ## Handle space
    ## If the current string is not empty, add the token
    if l.current_string.len > 0:
        l.addToken(kind)

proc handleNewLine*[T: enum](l: var Lexer[T], c: char, kind: T = default(T)): void =
    ## Handle newline
    ## If the current string is not empty, add the token
    ## Add the newline token with the tabulation size as the value
    ## 
    ## Token($kind, "tabulation size")
    if l.current_string.len > 0:
        l.addToken()
    var indent_size = 0
    # check if next char is a space
    if l.position.index + 1 < l.source.len: 
        while l.source[l.position.index + 1] == ' ':
            indent_size += 1
            l.advance()
    l.addToken(kind, $indent_size)

proc handleBetween*[T: enum](l: var Lexer[T], c: char, kind: T): void =
    ## Handle between two chars
    ## Add the token depending of the string char identifier 
    ## 
    ## exemples: 
    ## - if the string chir identifier is '"', this function will add a token for what is inside the two '"'
    l.current_string = ""
    l.advance()
    while l.peek() != c:
        l.current_string.add(l.peek())
        l.advance()
    l.addToken(kind)

proc handleSimpleChar*[T: enum](l: var Lexer[T], c: char, kind: T): void =
    ## Handle simple char
    ## This will add a token for the char
    ## 
    ## exemple:
    ## - if the char is '=', this function will add a token for '=' with the proper kind
    l.addToken(kind, $c)

proc handleUntilEOL*[T: enum](l: var Lexer[T], c: char, kind: T): void =
    ## Handle comment
    ## This will add a token for the comment
    ## 
    ## It will look to the end of line to cut the string and add the token
    ## 
    ## exemple:
    ## - if the char is '#', this function will add a token with as value all the string until the end of the line
    l.current_string = ""
    l.advance()
    while l.peek() != '\n':
        l.current_string.add(l.peek())
        l.advance()
    l.addToken(kind)
