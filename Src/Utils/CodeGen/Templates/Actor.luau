return {
    TargetedWrapper = {
        Text = table.concat({
            "{{Prelude}}",
            "run_on_actor({{Actor}}, [[\n{{IndentedCode}}\n]])",
        }, "\n"),
        IndentLevel = 1,
    },
    GenericWrapper = {
        Text = table.concat({
            "{{Prelude}}",
            "for _, category in {getactors(), getdeletedactors and getdeletedactors() or {}} do",
            "    for _, actor in category do",
            "        run_on_actor(actor, [[\n{{IndentedCode}}\n]])",
            "    end",
            "end",
        }, "\n"),
        IndentLevel = 2,
    }
}