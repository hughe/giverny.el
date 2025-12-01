# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Giverny is an experimental Emacs interface to Claude Code. This project aims to integrate Claude Code capabilities directly into the Emacs editor environment.

## Architecture

Giverny uses a dual-buffer architecture:

1. **Comint Buffer (`*giverny-comint*`)**: Runs the Claude Code process with JSONL input/output format. This is the raw communication channel with Claude Code using these flags:
   ```
   claude --output-format=stream-json --input-format=stream-json --print --verbose
   ```

2. **Display Buffer (`*giverny*`)**: Read-only buffer that parses JSONL output from the comint buffer and presents it in a human-readable format. Auto-scrolls to show new messages.

### Key Components

- **giverny-comint-mode**: Derived from `comint-mode`, handles the Claude Code process and raw JSONL communication
- **giverny-mode**: Derived from `special-mode`, provides the read-only display interface
- **JSONL Processing**: Output filter (`giverny-process-output`) accumulates and parses streaming JSONL, handling partial lines correctly
- **Message Formatting**: `giverny-format-message` converts JSON structures to human-readable text

### Customization

- `giverny-claude-executable`: Path to Claude Code binary (default: "claude")
- `giverny-claude-args`: Arguments passed to Claude Code (configured for JSONL streaming)

## Development Commands

### Testing the Mode

1. Load the file in Emacs:
   ```elisp
   (load-file "giverny.el")
   ```

2. Start Giverny:
   ```
   M-x giverny-start
   ```

3. Send a message to Claude:
   ```
   M-x giverny-send-message
   ```

4. Navigate between buffers:
   ```
   M-x giverny-show-display  ; Show the human-readable output
   M-x giverny-show-comint   ; Show the raw JSONL communication
   ```

5. Stop Giverny:
   ```
   M-x giverny-stop
   ```

### File Structure

- `giverny.el`: Main implementation file containing all modes and functions
