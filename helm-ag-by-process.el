;;; -*- coding: utf-8; mode: emacs-lisp; lexical-binding: t; -*-
(eval-when-compile (require 'cl))
(require 'helm)

(defvar helm-ag-by-process-directory '())
(defvar helm-ag-by-process-option-list '())
(defvar helm-ag-by-process-current-command '())

(defvar helm-ag-by-process-source
  '((name . "helm-ag-by-process")
    (header-name . (lambda (name)
                     (format "%s (%s)" name helm-ag-by-process-current-command)))
    (real-to-display . helm-ag-by-process-remove-dir-name)
    (candidates-process . (lambda ()
                            (funcall helm-ag-by-process-function)))
    (candidates-in-buffer)
    (delayed)))

(defun helm-ag-by-process-remove-dir-name (line)
  (let* ((all (split-string line ":"))
         (path    (file-relative-name (nth 0 all)))
         (num     (nth 1 all))
         (content (nth 2 all)))
    (mapconcat 'identity (list path num content) ":")))

(defvar helm-ag-by-process-actions
  '((:open
     (("Open File" . (lambda (candidate)
                       (helm-ag-find-file-action candidate 'find-file)))
      ("Open File Other Window" .
       (lambda (candidate)
         (helm-ag-find-file-action candidate 'find-file-other-window)))))
    (:move
     (("Move the line" . (lambda (line)
                           (string-match "^\\([0-9]*\\)\\(:\\|-\\)" line)
                           (goto-char (point-min))
                           (forward-line (1- (string-to-number
                                              (match-string 1 line))))))))))

(defvar helm-ag-by-process-get-command
  (lambda (pattern)
    (let*
        ((set-attribute
          (lambda (attr)
            (helm-attrset 'action
                          (car
                           (assoc-default attr helm-ag-by-process-actions))
                          helm-ag-by-process-source)))
         (patterns (split-string pattern))
         (dir-or-file helm-ag-by-process-directory)
         (create-ag-command
          (lambda (minibuffer-patterns)
            (loop for ag = "ag --nocolor --nogroup" then "ag --nocolor"
                  for options = (car helm-ag-by-process-option-list) then " "
                  for search-word in minibuffer-patterns
                  for d-f = dir-or-file then ""
                  collect (concat ag " " options " \"" search-word "\" " d-f))))
         (ag-commands
          (mapconcat 'identity (funcall create-ag-command patterns) " | ")))
      (if (and (file-exists-p dir-or-file) (not (file-directory-p dir-or-file)))
          (funcall set-attribute :move)
        (funcall set-attribute :open))
      (setq helm-ag-by-process-current-command ag-commands)
      ag-commands)))

(defvar helm-ag-by-process-function
  (lambda ()
    (start-process
     "emacs-helm-ag-process" nil "/bin/sh" "-c"
     (funcall helm-ag-by-process-get-command helm-pattern))))

(defvar helm-ag-by-process-keymap
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map helm-map)
    (define-key map (kbd "C-o") 'helm-ag-by-process-change-option)
    map))

(defun helm-ag-by-process (&optional file-or-directory)
  (interactive)
  (setq helm-ag-by-process-directory (or file-or-directory default-directory))
  (helm :sources helm-ag-by-process-source
        :prompt "ag: "
        :buffer "*helm ag process*"
        :keymap helm-ag-by-process-keymap))

(defun helm-ag-by-process-current-file ()
  (interactive)
  (helm-ag-by-process buffer-file-name))

(defun helm-ag-by-process-change-option ()
  (interactive)
  (setq helm-ag-by-process-option-list
        (append
         (cdr helm-ag-by-process-option-list)
         (list (car helm-ag-by-process-option-list))))
  (helm-update))

(provide 'helm-ag-by-process)
