type
    Token*[T: enum] = object
        kind*: T
        value*: string
        