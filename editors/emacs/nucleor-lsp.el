;;; nucleor-lsp.el --- LSP integration for Nucleor (.nr) files

;;; Commentary:
;;; Loads nucleor-lsp.exe via lsp-mode for .nr files.
;;; Requires (use-package lsp-mode) installed.

;;; Code:

(require 'lsp-mode)

(define-derived-mode nucleor-mode prog-mode "Nucleor"
  "Major mode for Nucleor source files.")

(add-to-list 'auto-mode-alist '("\\.nr\\'" . nucleor-mode))

(add-to-list 'lsp-language-id-configuration '(nucleor-mode . "nucleor"))

(lsp-register-client
 (make-lsp-client
  :new-connection (lsp-stdio-connection "nucleor-lsp.exe")
  :major-modes '(nucleor-mode)
  :server-id 'nucleor-lsp))

(add-hook 'nucleor-mode-hook #'lsp-deferred)

(provide 'nucleor-lsp)
;;; nucleor-lsp.el ends here
