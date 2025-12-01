;;; giverny.el --- An Emacs interface to Claude Code -*- lexical-binding: t; -*-

;; Copyright (C) 2025

;; Author: Hugh Emberson, Claude (Anthropic)
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: ai, tools
;; URL: https://github.com/hugh/giverny

;;; Commentary:

;; Giverny provides an *experimental* Emacs interface to Claude Code.
;; It runs Claude Code in a comint buffer and displays the output in a
;; human-readable format in a separate buffer.

;;; Code:

(require 'comint)
(require 'json)

;;; Customization

(defgroup giverny nil
  "Interface to Claude Code."
  :group 'tools
  :prefix "giverny-")

(defcustom giverny-claude-executable "claude"
  "Path to the Claude Code executable."
  :type 'string
  :group 'giverny)


;;; Buffer names

(defconst giverny-comint-buffer-name "*giverny-comint*"
  "Name of the comint buffer running Claude Code.")

(defconst giverny-display-buffer-name "*giverny*"
  "Name of the display buffer showing Claude Code output.")

(setq giverny-claude-args ;; This should not be customizable, I think.
  '("--output-format=stream-json"
    "--input-format=stream-json"
    "--print"
    "--verbose")
   )

;;; Comint setup

(defvar giverny-comint-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map comint-mode-map)
    map)
  "Keymap for `giverny-comint-mode'.")

(define-derived-mode giverny-comint-mode comint-mode "Giverny-Comint"
  "Major mode for the Giverny comint buffer.
This buffer runs Claude Code with JSONL input/output."
  (setq comint-prompt-regexp "^")
  (setq comint-input-sender 'giverny-comint-input-sender)
  (setq comint-process-echoes nil)
  (add-hook 'comint-output-filter-functions 'giverny-process-output nil t))

(defun giverny-comint-input-sender (proc string)
  "Send STRING to Claude Code process PROC as JSONL."
  (comint-simple-send proc string))

;;; Display buffer setup

(defvar-local giverny-prompt-marker nil
  "Marker for the input prompt position.")

(defvar giverny-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map text-mode-map)
    (define-key map (kbd "RET") 'giverny-send-input)
    map)
  "Keymap for `giverny-mode'.")

(define-derived-mode giverny-mode text-mode "Giverny"
  "Major mode for displaying Claude Code output.
This buffer displays the human-readable output from Claude Code.

\\{giverny-mode-map}"
  (setq buffer-read-only nil)
  (setq-local truncate-lines nil)
  (setq-local word-wrap t)
  (setq giverny-prompt-marker (make-marker)))

(defun giverny-prompt-line-start ()
  "Return the position of the start of the line containing the prompt."
  (when giverny-prompt-marker
    (save-excursion
      (goto-char (marker-position giverny-prompt-marker))
      (forward-line 0)
      (point))))

(defun giverny-update-read-only ()
  "Make everything above the prompt read-only."
  (when giverny-prompt-marker
    (let ((prompt-start (giverny-prompt-line-start))
          (inhibit-read-only t))
      (when prompt-start
        (put-text-property (point-min) prompt-start 'read-only t)
        (put-text-property (point-min) prompt-start 'rear-nonsticky t)))))

(defun giverny-insert-prompt ()
  "Insert the input prompt at the end of the buffer."
  (let ((inhibit-read-only t)
        (prompt-start (point-max)))
    (goto-char (point-max))
    (unless (bolp)
      (insert "\n")
      (setq prompt-start (point)))
    (insert "> ")
    ;; Set marker AFTER the "> " so it points to where input starts
    (set-marker giverny-prompt-marker (point))
    (set-marker-insertion-type giverny-prompt-marker nil)
    ;; Make everything before the input area read-only
    (when (> prompt-start (point-min))
      (put-text-property (point-min) prompt-start 'read-only t)
      (put-text-property (point-min) prompt-start 'rear-nonsticky t))
    (put-text-property prompt-start giverny-prompt-marker 'read-only t)
    (put-text-property prompt-start giverny-prompt-marker 'rear-nonsticky t)))

(defun giverny-send-input ()
  "Send input from the prompt to Claude Code."
  (interactive)
  (when giverny-prompt-marker
    (let* ((input-start (marker-position giverny-prompt-marker))
           (input (buffer-substring-no-properties input-start (point-max)))
           (prompt-line-start (save-excursion
                                (goto-char input-start)
                                (forward-line 0)
                                (point))))
      (when (> (length (string-trim input)) 0)
        (let ((inhibit-read-only t))
          ;; Send to Claude
          (giverny-send-message (string-trim input))

          ;; Delete the old prompt and input
          (delete-region prompt-line-start (point-max))

          ;; Insert the user's message
          (goto-char (point-max))
          (insert "You: " (string-trim input) "\n\n")

          ;; Insert new prompt
          (giverny-insert-prompt)

          ;; Update read-only region
          (giverny-update-read-only))))))

;;; Output processing

(defvar giverny--output-buffer ""
  "Buffer for accumulating partial JSONL output.")

(defun giverny-process-output (output)
  "Process OUTPUT from Claude Code comint buffer.
Parse JSONL and update the display buffer."
  (setq giverny--output-buffer (concat giverny--output-buffer output))

  ;; Process complete lines
  (let ((lines (split-string giverny--output-buffer "\n")))
    ;; Keep the last incomplete line in the buffer
    (setq giverny--output-buffer (car (last lines)))

    ;; Process all complete lines
    (dolist (line (butlast lines))
      (when (> (length line) 0)
        (giverny-handle-jsonl-line line))))

  ;; Return nil to allow other output filters to run
  nil)

(defun giverny-display-text (text)
  "Display TEXT in the giverny display buffer above the prompt."
  (when text
    (let ((display-buf (get-buffer-create giverny-display-buffer-name)))
      (with-current-buffer display-buf
        (unless (eq major-mode 'giverny-mode)
          (giverny-mode))
        (let ((inhibit-read-only t)
              (at-end (= (point) (point-max)))
              (insert-pos (or (giverny-prompt-line-start) (point-max))))
          (save-excursion
            (goto-char insert-pos)
            (insert text))
          ;; Update read-only region
          (giverny-update-read-only)
          ;; Auto-scroll if we were at the end
          (when at-end
            (goto-char (point-max))))))))

(defun giverny-handle-jsonl-line (line)
  "Handle a single JSONL LINE from Claude Code."
  (condition-case err
      (let* ((data (json-read-from-string line))
             (msg-type (alist-get 'type data))
             (handler (intern (concat "giverny-handle-" msg-type))))
        ;; Call type-specific handler if it exists
        (let ((text (if (fboundp handler)
                       (funcall handler data)
                     ;; Unknown message type - return JSON
                     (concat (json-encode data) "\n"))))
          (giverny-display-text text)))
    (error
     (message "Giverny: Failed to parse JSON: %s" (error-message-string err)))))

;;; Message type handlers

(defun giverny-handle-system (data)
  "Handle system message DATA.
Returns nil to ignore system messages."
  ;; Ignore system messages for now
  nil)

(defun giverny-handle-result (data)
  "Handle result message DATA.
Returns error text if this is an error, nil otherwise."
  (let ((result-text (alist-get 'result data))
        (is-error (alist-get 'is_error data)))
    ;; Only return text if it's an error
    (when (and (eq is-error t) result-text)
      (concat "ERROR: " result-text "\n\n"))))

(defun giverny-handle-assistant (data)
  "Handle assistant message DATA.
Returns the formatted assistant message text."
  (let* ((message (alist-get 'message data))
         (content (alist-get 'content message))
         (text-parts '()))
    ;; Collect text from all content blocks
    (dotimes (i (length content))
      (let* ((block (aref content i))
             (block-type (alist-get 'type block))
             (text (alist-get 'text block)))
        (when (equal block-type "text")
          (push text text-parts))))
    ;; Return combined text with extra newline
    (when text-parts
      (concat (mapconcat 'identity (nreverse text-parts) "\n") "\n\n"))))

(defun giverny-handle-user (data)
  "Handle user message DATA (typically tool results).
Returns the formatted tool output text."
  (let* ((tool-use-result (alist-get 'tool_use_result data))
         (stdout (alist-get 'stdout tool-use-result))
         (stderr (alist-get 'stderr tool-use-result))
         (is-error (alist-get 'is_error tool-use-result))
         (output-parts '()))
    ;; Add stdout if present
    (when (and stdout (> (length stdout) 0))
      (push stdout output-parts))
    ;; Add stderr if present
    (when (and stderr (> (length stderr) 0))
      (push (concat "STDERR:\n" stderr) output-parts))
    ;; Return combined output
    (when output-parts
      (concat (mapconcat 'identity (nreverse output-parts) "\n") "\n\n"))))

;;; Commands

;;;###autoload
(defun giverny-start ()
  "Start Claude Code in a comint buffer."
  (interactive)

  ;; Create or switch to comint buffer
  (let* ((buffer (get-buffer-create giverny-comint-buffer-name))
         (proc (get-buffer-process buffer)))

    ;; Kill existing process if running
    (when (and proc (process-live-p proc))
      (delete-process proc))

    ;; Start Claude Code process
    (with-current-buffer buffer
      (giverny-comint-mode)
      (setq giverny--output-buffer "")

      ;; Display the working directory and command being run
      (insert (format "Directory: %s\n" default-directory))
      (let ((command-string (concat giverny-claude-executable " "
                                   (mapconcat 'identity giverny-claude-args " "))))
        (insert (format "Running: %s\n\n" command-string)))

      ;; Use make-process for explicit pipe control
      (let ((process (make-process
                      :name "giverny"
                      :buffer buffer
                      :command (cons giverny-claude-executable giverny-claude-args)
                      :connection-type 'pipe
                      :filter 'comint-output-filter
                      :sentinel (lambda (proc event)
                                  (message "Giverny process: %s" event)))))
        process))

    ;; Create and display the output buffer
    (let ((display-buf (get-buffer-create giverny-display-buffer-name)))
      (with-current-buffer display-buf
        (giverny-mode)
        (erase-buffer)
        (giverny-insert-prompt))
      (display-buffer display-buf))

    ;; Show comint buffer too
    (switch-to-buffer buffer)

    (message "Giverny started with Claude Code")))

;;;###autoload
(defun giverny-stop ()
  "Stop the Claude Code process."
  (interactive)
  (let* ((buffer (get-buffer giverny-comint-buffer-name))
         (proc (and buffer (get-buffer-process buffer))))
    (when (and proc (process-live-p proc))
      (delete-process proc)
      (message "Giverny stopped"))
    (unless proc
      (message "Giverny is not running"))))

;;;###autoload
(defun giverny-send-message (message)
  "Send MESSAGE to Claude Code as JSONL."
  (interactive "sMessage: ")
  (let* ((buffer (get-buffer giverny-comint-buffer-name))
         (proc (and buffer (get-buffer-process buffer))))
    (if (and proc (process-live-p proc))
        (let ((jsonl (json-encode `((type . "user")
                                   (message . ((role . "user")
                                              (content . [((type . "text")
                                                          (text . ,message))])))))))
          ;; Echo the sent message to the comint buffer
          (with-current-buffer buffer
            (goto-char (point-max))
            (insert "SENT: " jsonl "\n"))
          ;; Send the message
          (comint-send-string proc (concat jsonl "\n")))
      (error "Giverny is not running. Start it with M-x giverny-start"))))

;;;###autoload
(defun giverny-show-display ()
  "Show the Giverny display buffer."
  (interactive)
  (let ((buffer (get-buffer giverny-display-buffer-name)))
    (if buffer
        (switch-to-buffer buffer)
      (message "Giverny display buffer does not exist. Start Giverny first."))))

;;;###autoload
(defun giverny-show-comint ()
  "Show the Giverny comint buffer."
  (interactive)
  (let ((buffer (get-buffer giverny-comint-buffer-name)))
    (if buffer
        (switch-to-buffer buffer)
      (message "Giverny comint buffer does not exist. Start Giverny first."))))

;;;###autoload
(defun giverny-reload ()
  "Reload giverny.el and restart Giverny in the same directory."
  (interactive)
  (let* ((comint-buffer (get-buffer giverny-comint-buffer-name))
         (display-buffer (get-buffer giverny-display-buffer-name))
         (saved-dir (when comint-buffer
                     (with-current-buffer comint-buffer
                       default-directory)))
         (was-running (and comint-buffer
                          (get-buffer-process comint-buffer)
                          (process-live-p (get-buffer-process comint-buffer)))))
    ;; Stop if running
    (when was-running
      (giverny-stop))

    ;; Kill both buffers to clear all state
    (when display-buffer
      (kill-buffer display-buffer))
    (when comint-buffer
      (kill-buffer comint-buffer))

    ;; Save and reload the giverny.el file
    (let ((giverny-buffer (get-buffer "giverny.el")))
      (if giverny-buffer
          (with-current-buffer giverny-buffer
            (save-buffer)
            (load-file (buffer-file-name))
            (message "Reloaded giverny.el from %s" (buffer-file-name)))
        (error "Cannot find giverny.el buffer")))

    ;; Restart if it was running
    (when was-running
      (when saved-dir
        (setq default-directory saved-dir))
      (giverny-start))))

(provide 'giverny)
;;; giverny.el ends here
