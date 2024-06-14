import token

type 
    ## The Node Parser Proc is a procedure that do something with the current token on the context
    ## It purpose is generaly to create a node and add it to the nodes of the context
    ## But it can also interact with the context in other ways like moving the index, deleting tokens and node etc
    NodeParserProc*[N: ref object, T: enum] = proc (c: var Context[N,T], t: Token[T])
    ## The Node Parser Config is a configuration for a node parser
    ## It helps to associate a token kind with a node parser proc
    ## It is used in the context to store the node parsers
    NodeParserConfig*[N: ref object, T: enum] = object
        tokenKind: T
        `proc`: NodeParserProc[N, T]
    ## The Context is a structure that store the tokens, the nodes and the index of the current token
    ## It also store the node parsers that will be used to parse the tokens
    ## The context is used to parse the tokens and create the nodes
    ## The context is passed to the node parsers to allow them to interact with it
    Context*[N: ref object, T: enum] = object
        nodes*: seq[N]
        tokens*: seq[Token[T]]
        index*: int
        node_parsers*: seq[NodeParserConfig[N, T]]

proc checkNodeParsers*[N: ref object, T: enum](context: var Context[N, T]) = 
    ## Check that there are no duplicated parsers for the same token kind
    var reviewed: seq[T] # store the token kinds that have been reviewed
    for parser in context.node_parsers: # iterate over the parsers
        if not reviewed.contains(parser.tokenKind): # check if the token kind has been reviewed
            reviewed.add(parser.tokenKind) # add the token kind to the reviewed list
        else: # if the token kind has been reviewed
            raise newException(Exception, "Duplicated parser for token kind: " & $parser.tokenKind) # raise an exception

proc addNodeParser*[N: ref object, T: enum](context: var Context[N, T], tokenKind: T, `proc`: NodeParserProc[N, T]) =
    ## Helper to add a node parser to the context
    let config = NodeParserConfig[N, T](tokenKind: tokenKind, `proc`: `proc`)
    context.node_parsers.add(config)
    # check that there are no duplicated parsers
    checkNodeParsers(context)    
        
proc advance*[N: ref object, T: enum](context: var Context[N, T], l: int = 1) =
    ## Move the index of the context
    ## args:
    ## - context: the context to advance
    ## - l: the number of positions to advance relative to the current index
    if context.index + l < context.tokens.len:
        context.index += l
    else :
        context.index += 1

proc peek*[N: ref object, T: enum](context: Context[N, T], relative_posistion: int = 0): Token[T] =
    ## Get the token at the current index
    ## args:
    ## - context: the context to get the token from
    ## - relative_posistion: the relative position of the token to get
    if context.index < context.tokens.len:
        result = context.tokens[context.index + relative_posistion]

proc parseToken*[N: ref object, T: enum](context: var Context[N,T]) =
    ## Parse the current token based on the config of the context
    # get the current token
    let token = context.peek()
    # find the parser for the token
    for parser in context.node_parsers:
        if token.kind == parser.tokenKind:
            parser.proc(context, token)
            break

proc parseContext*[N: ref object, T: enum](context: var Context[N, T]) =
    ## Parse the context
    ## Iterate over the tokens and parse them
    while context.index < context.tokens.len:
        parseToken(context)
        advance(context)

proc reuseContext*[N: ref object, T: enum](context: Context[N, T], tokens: seq[Token[T]]): Context[N, T] =
    ## Create a new context with the same node parsers 
    ## args:
    ## - context: the context to reuse
    ## - tokens: the tokens to use in the new context
    ## returns:
    ## - a new context with the same node parsers
    result.node_parsers = context.node_parsers
    result.tokens = tokens
    result.index = 0
