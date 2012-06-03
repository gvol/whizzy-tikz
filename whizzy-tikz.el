
;; Overwrite -- this should be an advice, but I want it here for
;; reference.  At least for now
(defun whizzy-edit (command name first line  file type dx dy)
  (if (string-match "tikz" name)
      (whizzy-tikz-match command name first line file type dx dy)
    (let ((x) (y) (regexp))
      ;; (message "command=%S name=%S[%S] line=%S file=%S"
      ;;    command name first line file)
      (if (string-equal name "") nil
        (setq name (concat " *\n? *\\[" (regexp-quote name) "\\]")))
      (cond
       ((equal type 'moveto) (setq x "x" y "y"))
       ((equal type 'resizetop) (setq x "w" y "h"))
       ((equal type 'resizebot) (setq x "w" y "d"))
       (t (error "whizzy-edit")))
      (if (string-match "^\\([xywhd]\\)=1$" first)
          (setq first
                (concat "\\(" (regexp-quote first) "\\|"
                        (regexp-quote (match-string 1 first)) "\\)"))
        (setq first (regexp-quote first)))
      (setq regexp
            (concat (regexp-quote command) "\\*?" name
                    " *\n? *{\\([^}]*\\b" first "\\(,[^}]*\\)*\\)}"))
      ;; (show regexp)
      ;; (show file)
      ;; (message "%S" regexp)
      (save-window-excursion
        (save-excursion
          (and (whizzy-goto-file file)
               (prog1 (goto-line (string-to-number line))
                 (end-of-line))
               (show 'here)
               ;; (insert "xxx")
               (or (re-search-backward regexp (point-min) t)
                   (re-search-forward regexp (point-max) t))
               (show 'there)
               (show (buffer-substring-no-properties (match-beginning 1) (match-end 1)))
               (let ((begin  (match-beginning 1))
                     (modified  (buffer-modified-p))
                     (edited))
                 (goto-char begin)
                 (message "%S=%S %S=%S" x dx y dy)
                 (setq edited (whizzy-edit-field x dx))
                 (setq edited (or (whizzy-edit-field y dy) edited))
                 (unless (not edited)
                   (if (or modified
                           (equal (whizzy-get whizzy-active-buffer)
                                  (current-buffer)))
                       (whizzy-observe-changes)
                     (save-buffer)
                     (whizzy-reslice))))))))))



(defun whizzy-tikz-match (command name first line file type dx dy)
  (save-window-excursion
    (save-excursion
      (show file)
      (show name)
      (and (prog1 (whizzy-goto-file file)
             (widen))
           (goto-char (point-min))
           (prog1 (forward-line (1- (string-to-number line)))
             (end-of-line))

           ;; (narrow-to-defun)
           (show 'here)
           (sit-for 2)
           (let ((regexp "\\(?:at *\\)?(\\(-?[0-9.]+,-?[0-9.]+\\))")
                 (replacement (format "%s,%s" dx dy))
                 (modified  (buffer-modified-p)))

             (when
                 (or (re-search-backward regexp (point-min) t)
                     (re-search-forward regexp (point-max) t))

               ;; (show 'there)
               ;; (sit-for 5)
               (let (;(begin  (match-beginning 1))
                     (edited
                      ;;  (save-match-data
                      ;;    (and (string= (match-string-no-properties 1) dx)
                      ;;         (string= (match-string-no-properties 2) dy))))
                      t)
                     )
                 (show (match-string-no-properties 0))
                 ;; (show (match-beginning 1))
                 ;; (show (match-end 1))
                 (show (replace-match replacement t t nil 1))
                 ;; Have to figure out how to account for center vs lower left
                 ;; (replace-match dx t t nil 1)
                 ;; (replace-match dy t t nil 2) ;or the other order??? Can you do both?
                 ;; (goto-char begin)
                 ;; (message "%S=%S %S=%S" x dx y dy)
                 ;; (setq edited (whizzy-edit-field x dx))
                 ;; (setq edited (or (whizzy-edit-field y dy) edited))
                 (unless (not edited)
                   (if (or modified
                           (equal (whizzy-get whizzy-active-buffer)
                                  (current-buffer)))
                       (whizzy-observe-changes)
                     (save-buffer)
                     (whizzy-reslice))))))))))
