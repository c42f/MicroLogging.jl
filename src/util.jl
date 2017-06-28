function propagate_sourceloc(sourceloc, ex)
    if ex isa Expr
        if ex.head == :macrocall
            ex.args[2] = sourceloc
        else
            map!(e->propagate_sourceloc(sourceloc,e), ex.args, ex.args)
        end
    end
    ex
end

"""
    @propagate_sourceloc(quoted_block)

Make all macro calls inside `quoted_block` see the `__source__` location of
the parent macro call.  In particular, this makes the `@__LINE__` and
`@__FILE__` macros return the location where the parent macro was invoked.
For example:

```
macro example()
    @propagate_sourceloc quote
        @__LINE__
    end
end

@example
```

This produces line 7 (the place where `@example` was called) rather than line
3 (the location of the `@__LINE__` invocation).
"""
macro propagate_sourceloc(ex)
    @static if Compat.macros_have_sourceloc
        :(propagate_sourceloc($(esc(:__source__)), $(esc(ex))))
    else
        esc(ex)
    end
end
