import strutils, sequtils
import ../src/lexer, ../src/token, ../src/node_parser, ../src/lexer_utils

type 
    TokenKind = enum
        identifier
        assign
        type_assign
        open_paren
        close_paren
        separator
        comment
        newline
        STRING
        FLOAT
        INT
        
        
type 
    NodeKind = enum
        program
        assign
        identifier
        `block`
        `string`
    Node = ref object of RootObj 
        case kind: NodeKind
        of program, `block`:
            childrens: seq[Node]
        of identifier:
            value: string
            `type`: string
        of assign:
            key: Node
            nodeValue: Node
        of `string`:
            strValue: string

proc addTabulation(s: string): string =
    result = s.replace("\n", "\n\t")


proc `$`(n: Node): string =
    case n.kind
    of program, `block`:
        result = "Node(kind: " & $n.kind & ")" & " childrens: " & $n.childrens.len
        for child in n.childrens:
            result.add("\n\t" & addTabulation($child))
    of assign:
        result = "Node(kind: " & $n.kind & ")" & "\n\tkey: " & addTabulation($n.key) & "\n\tvalue: " & addTabulation($n.nodeValue)
    of identifier:
        result = "Node(kind: " & $n.kind & ")" & "\n\tvalue: " & n.value & "\n\ttype: " & addTabulation(n.`type`)
    of `string`:
        result = "Node(kind: " & $n.kind & ")" & "\n\tvalue: " & addTabulation(n.strValue)

proc handleBlock(context: var Context[Node, TokenKind], token: Token[TokenKind]) =
    # create a new context with the tokens of the block
    # get all token kinds same as this one
    var tokens : seq[Token[TokenKind]]
    var new_block_found = false
    while (not new_block_found):
        # get the next token
        context.advance()
        if context.index >= context.tokens.len:
            break
        let next_token = context.peek()
        if next_token.kind != token.kind:
            tokens.add(next_token)
        elif next_token.value != token.value:
            tokens.add(next_token)
        else:
            new_block_found = true
            context.advance(-1)
    # create a new context with the tokens of the block
    var new_context = reuseContext[Node, TokenKind](context, tokens)
    new_context.parseContext()
    if new_context.nodes.len > 1: 
        # add the block to the nodes
        context.nodes.add(Node(kind: `block`, childrens: new_context.nodes))
    elif new_context.nodes.len == 1:
        # add the only node to the nodes
        context.nodes.add(new_context.nodes[0])

proc handleIdentifier(context: var Context[Node, TokenKind], token: Token[TokenKind]) =
    var node = Node(kind: identifier, value: token.value)
    # if the next token is a type assign, add the type to the identifier
    if context.index + 1 < context.tokens.len:
        let next_token = context.peek(1)
        if next_token.kind == type_assign:
            context.advance(2)
            let type_token = context.peek()
            if type_token.kind != identifier:
                raise newException(Exception, "Expected a type after type assign")
            node.`type` = type_token.value
    context.nodes.add(node)
        
proc handleAssign(context: var Context[Node, TokenKind], token: Token[TokenKind]) =
    # chekc that only one identifier is in the list
    if context.nodes.filterIt(it.kind == identifier).len != 1:
        raise newException(Exception, "Only one identifier is allowed in the left side of an assign")
    # get the identifier
    let ident = context.nodes.filterIt(it.kind == identifier)[0]
    # delete it from the nodes
    context.nodes.del(context.nodes.find(ident))
    # get the value by creating a new context with the right side of the assign
    var new_context = reuseContext[Node, TokenKind](context, context.tokens[(context.index + 1)..context.tokens.len-1])
    # advance to the end of the assign
    context.advance(context.tokens.len - context.index - 1)
    new_context.parseContext()
    # check that there is only one node in the new context
    if new_context.nodes.len != 1:
        raise newException(Exception, "Only one node is allowed in the right side of an assign")
    # create the assign node
    let node = Node(kind: assign, key: ident, nodeValue: new_context.nodes[0])
    context.nodes.add(node)

proc handleString(context: var Context[Node, TokenKind], token: Token[TokenKind]) =
    context.nodes.add(Node(kind:`string`, strValue: token.value))

proc handleOpenParen(context: var Context[Node, TokenKind], token: Token[TokenKind]) =
    # create a new context with the tokens of the block
    # get all token until the close paren
    var tokens : seq[Token[TokenKind]]
    var new_block_found = false
    while (not new_block_found):
        # get the next token
        context.advance()
        if context.index >= context.tokens.len:
            break
        let next_token = context.peek()
        if next_token.kind != close_paren:
            tokens.add(next_token)
        else:
            new_block_found = true
    # create a new context with the tokens of the block
    var new_context = reuseContext[Node, TokenKind](context, tokens)
    new_context.parseContext()
    if new_context.nodes.len > 0: 
        # add the block to the nodes
        context.nodes.add(Node(kind: `block`, childrens: new_context.nodes))
        
proc main() =
    # test the lexer
    # get the file path for test file
    const filePath = "/workspace/exemples/mocks/test.mot"
    # read the file
    let source = readFile(filePath)
    # create a lexer
    var lexer = initLexer[TokenKind](source)
    addCharConfig[TokenKind](lexer, handleSpace, @[' '])
    addCharConfig[TokenKind](lexer, handleNewLine, @['\n'], newline)
    addCharConfig[TokenKind](lexer, handleSimpleChar, @['='], assign)
    addCharConfig[TokenKind](lexer, handleSimpleChar, @[':'], type_assign)
    addCharConfig[TokenKind](lexer, handleSimpleChar, @['('], open_paren)
    addCharConfig[TokenKind](lexer, handleSimpleChar, @[')'], close_paren)
    addCharConfig[TokenKind](lexer, handleSimpleChar, @[';', ','], separator)
    addCharConfig[TokenKind](lexer, handleUntilEOL, @['#'], comment)
    addCharConfig[TokenKind](lexer, handleBetween, @['"'], STRING)

    lexer.lex()
    for token in lexer.tokens:
        echo token

    echo "### PARSER ###"
    # create a context
    var context: Context[Node, TokenKind]
    context.tokens = lexer.tokens
    context.addNodeParser(newline, handleBlock)
    context.addNodeParser(identifier, handleIdentifier)
    context.addNodeParser(STRING, handleString)
    context.addNodeParser(assign, handleAssign)
    context.addNodeParser(open_paren, handleOpenParen)
    context.parseContext()
    for node in context.nodes:
        echo $node

main()