proc removeDuplicates*[T](seq: seq[T]): seq[T] =
    ## Remove duplicates from a sequence
    ## 
    ## Args:
    ## - seq: The sequence to remove duplicates from
    ## 
    ## Returns:
    ## - A sequence with no duplicates
    ## 
    ## Example:
    ## 
    ## ```
    ## var seq = @[1, 2, 3, 1, 2, 3]
    ## var result = removeDuplicates(seq)
    ## echo result
    ## ```
    ## 
    ## Output:
    ## 
    ## ```
    ## @[1, 2, 3]
    ## ```
    ## 
    for i in seq:
        if i notin result:
            result.add(i)