# Investigation: `hookfunction` Crashes on Yielded Threads in Luau

## Overview

When using memory-manipulation functions like `hookfunction` to intercept or modify a function in Luau, a fatal crash (e.g., Access Violation/Segfault) can occur if the target function is currently yielding.

The provided script reproduces this vulnerability:

```lua
local f = function()
    task.wait(3)
    return 'hi'
end
task.spawn(f)
task.wait(0.5)
hookfunction(f, function() end) -- crash in 2.5 seconds?
```

This document explains the internal mechanisms of the Luau VM that lead to this crash.

## Internal Mechanisms

### 1. Yielding and the `CallInfo` Struct
When `task.spawn(f)` is called, the Luau VM creates a new thread (coroutine) and begins executing `f`. When `task.wait(3)` is encountered, the thread yields.
During a yield, the current execution state of the function is saved into a `CallInfo` struct within the `lua_State`.

```cpp
typedef struct CallInfo
{
    StkId base;    // base for this function
    StkId func;    // function index in the stack
    StkId top;     // top for this function
    const Instruction* savedpc; // Program Counter (Instruction Pointer)
    ...
} CallInfo;
```

Crucially, `savedpc` holds a raw pointer to the next bytecode instruction to execute inside the original function's prototype (`Proto`). The `func` field points to the `Closure` object on the Lua stack.

### 2. Mutating the Closure (`hookfunction`)
While the thread is suspended, `hookfunction(f, target)` is executed. In most exploit/executor environments, `hookfunction` works by directly mutating the internal `Closure` GC object of `f` in-place.

```cpp
typedef struct Closure
{
    CommonHeader;
    uint8_t isC;
    ...
    union
    {
        struct { lua_CFunction f; lua_Continuation cont; ... } c;
        struct { struct Proto* p; TValue uprefs[1]; } l;
    };
} Closure;
```

When `hookfunction` swaps `f` with the target function, it overwrites the `isC` flag and the internal union (replacing the `Proto* p` with a new `Proto*`, or with a C function pointer `c.f`). However, the `CallInfo` of the suspended thread is entirely unaware of this mutation. Its `savedpc` remains pointing to the old bytecode memory.

### 3. Thread Resumption and State Mismatch
After 3 seconds, the task scheduler resumes the yielded thread. The VM re-enters `luau_execute` and restores the state from the `CallInfo`:

```cpp
// From lvmexecute.cpp
pc = L->ci->savedpc;
cl = clvalue(L->ci->func);
base = L->base;
k = cl->l.p->k;
```

This creates a catastrophic state mismatch:
- `pc` points to the **old** bytecode instructions.
- `cl` is the **mutated** `Closure` object.
- `k` (the constants array) points to the constants of the **new** `Proto` (if it's still a Lua closure), or garbage (if it's now a C closure).

### 4. The Crash
Depending on the target function, the crash occurs in one of the following ways:

#### A. Lua-to-C Hook (Access Violation)
If `hookfunction` replaces the Lua closure with a C closure, `cl->isC` becomes `1`. However, `luau_execute` assumes it is running a Lua function. When it attempts to read `cl->l.p->k` to cache the constants table, it accesses the `Closure` union as a `Proto*`. Since the union now holds a `lua_CFunction` pointer, dereferencing `p->k` results in reading from an invalid memory address, causing an immediate segmentation fault.

#### B. Lua-to-Lua Hook (Out-of-Bounds Memory Access)
If the hook target is another Lua function, the union correctly holds a `Proto*`, but it is the *new* function's prototype. The VM continues fetching instructions from the *old* `pc`. When it executes an instruction that requires a constant (e.g., `OP_GETK`) or an upvalue, it uses the index from the *old* bytecode to look up an entry in the *new* prototype's arrays (`cl->l.p->k` or upvalues). Since the new prototype has a different layout and likely smaller arrays, this leads to an out-of-bounds read or write, corrupting memory and crashing the VM.

#### C. Use-After-Free
When `hookfunction` overwrites the `Proto*` reference in the closure, the old `Proto` may no longer be referenced anywhere in the VM. If a garbage collection cycle runs during the yield, the old `Proto` (and its bytecode) is freed. Upon resumption, `savedpc` points to freed memory, leading to a classic Use-After-Free (UAF) crash as the VM attempts to execute garbage data as bytecode.

## Conclusion
The crash is an inherent consequence of in-place `Closure` mutation. Yielded threads retain deep, raw pointers (`savedpc`) to the internals of the `Closure` at the time they yielded. Altering the `Closure` out from under a sleeping thread breaks the assumptions of the VM's execution loop upon resumption, directly corrupting the callstack and execution context.