## ### POSITION ### ##
## Position represents a position in the source code
## It is used to keep track of the current position in the source code

type 
    Position* = object
        index*: int
        line*: int
        column*: int

proc initPosition*(): Position =
    result.index = 0

proc advance*(pos: var Position) =
    pos.index += 1