# Giverny - An Experimental Emacs Interface to Claude Code


# Architecture

Giverny runs Claude Code in a comint buffer called
`*giverny-comint*`. Cloud Code is configured to take its input as a
stream of JSONL objects and return its output as a stream of JSONL
objects.

A separate buffer "*giverny*' takes the messages written into the comment buffer
by Claude Code and decodes them and presents them in a human-readable
format. This buffer is read only.


# Instructions for Claude

Can you help me write this mode? We will need a mode for the Giverny
buffer And we will need to run the comint buffer.

Let's start by running Claude Code in a comint buffer with these flags: 

```
claude --output-format=stream-json --input-format=stream-json --print --verbose
```

