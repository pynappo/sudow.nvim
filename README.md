# sudow.nvim

Like [vim-suda](https://github.com/lambdalisue/vim-suda) but pops up a terminal. Useful if you setup sudo using
non-password authentication methods, such as a YubiKey.

It provides `:SuWrite`, which works like `:w` but roughly tries to emulate what `sudoedit` does (write to temp file,
copy to destination using elevated `cp` and `mv`).

# Requirements:

- System tools: `cp`, `mv`, POSIX-compliant shell or `fish`
- Neovim version: Likely `0.8` or above, but haven't tested on anything besides nightly.

# Installation:

lazy.nvim:

```lua
return {
    {
        "pynappo/sudow.nvim",
    }
}
```

vim.pack (nightly only, at time of writing):

```lua
vim.pack.add({
    "pynappo/sudow.nvim",
})
```

# Usage:

When needing to write but being denied due to lack of permissions, use `:SuWrite` instead.

# AI note:

This README is not AI-generated.

Chat log:

https://gemini.google.com/share/7b0dc9eb6c78
