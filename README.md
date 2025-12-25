# Giverny.el - An Experimental Emacs Interface to Claude Code


# Architecture

Giverny runs Claude Code in a comint buffer called
`*giverny-comint*`. Claude Code is configured to take its input as a
stream of JSONL objects and return its output as a stream of JSONL
objects.

A separate buffer "*giverny*' takes the messages written into the
comment buffer by Claude Code and decodes them and presents them in a
human-readable format. This buffer is mostly read only, only the area
where you can prompt is writable. It otherwise works like a normal
`text-mode` buffer.

# Issues

Written, almost entirely by Claude Code (CC).

Works nicely, *EXCEPT* that there is no easy way to grant permissions
to Claude Code when it is running using the JSON interface.  So it
would only work if you pre-configure the permissions or use
`--dangerously-skip-permissions` or select a bunch of permissions
before starting the process.

