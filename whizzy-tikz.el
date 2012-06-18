
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
               ;; (show 'here)
               ;; (insert "xxx")
               (or (re-search-backward regexp (point-min) t)
                   (re-search-forward regexp (point-max) t))
               ;; (show 'there)
               ;; (show (buffer-substring-no-properties (match-beginning 1) (match-end 1)))
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


(defvar whizzy-tikz-environments
  '("tikzpicture"
    "scope"))

;; TODO: need to support things like \Vertex[]{} which don't terminate
;; with a semi-colon.  Should really check out
;; https://github.com/blerner/auc-tikz and see if that can parse it.
(defun whizzy-narrow-to-tikz ()
  "Currently only supports environment form of tikz.
Return nil if not in a tikz environment as defined by
`whizzy-tikz-environments'."
  (interactive)
  (let ((n 1)
        (env (LaTeX-current-environment)))
    ;; Limit to the current environment
    (while (and (not (member env whizzy-tikz-environments))
                (not (string= "document" env))
                (< n 10))
      (setq n (1+ n))
      (setq env (LaTeX-current-environment n)))
    ;; Narrow to the current environment
    (if (string= "document" env)
        nil ;; Couldn't narrow
      (narrow-to-region
       (save-excursion
         (let ((LaTeX-syntactic-comments nil))
           (dotimes (dummy n)
             (LaTeX-find-matching-begin)))
         ;; (sit-for 1)
         (point))
       (save-excursion
         (let ((LaTeX-syntactic-comments nil))
           (dotimes (dummy n)
             (LaTeX-find-matching-end)))
         (point)))

      ;; Now try to limit to the current statement.

      ;; This is not guaranteed to work since might have ; in node
      ;; name, comment etc.
      (let* ((b1 (save-excursion
                   (beginning-of-line)
                   (when (search-backward ";" nil t)
                       (forward-char 1))
                   (point)))
             (e1 (save-excursion
                   (beginning-of-line)
                   (search-forward ";" nil t) ;; Maybe not guaranteed to work since
                   ;; might have ; in node name etc.
                   (point)))
             (lep (line-end-position))
             ;; No because this will miss the ; at the end of the line!!!!
             (just-this-line (or (> e1 lep)
                                 (save-excursion
                                   (goto-char e1)
                                   (looking-at "\\s *\\(%\\|$\\)"))))
             (e2 (if just-this-line
                     e1
                   (save-excursion
                     (end-of-line)
                     (search-forward ";" nil t)
                     ;; Not guaranteed to work since might have
                     ;; semicolon in node name etc.
                     (point)))))
        (narrow-to-region b1 e2)))))

(defun whizzy-tikz-strip-trailing-zeros (string)
  "Return STRING stripped of trailing zeros and periods."
  (save-match-data
    (while (string-match "\\.?0+$" string)
      (setq string (replace-match "" t t string))))
  string)

;; These could certainly use some work
(defvar whizzy-tikz-node-regexp
  '(
    ;; strict seems pretty useless, but it could be used to validate
    ;; that one of the coordinates are close (assuming that one is a
    ;; number and the other is a macro).  Then it even prompt to
    ;; change the macro/forloop if desired.  This shouldn't be an
    ;; alist of regexps, but an alist of matching functions.  Then I
    ;; would have a similar alist of replacing functions, one of which
    ;; would be duplicate, one might change a macro, one might round
    ;; etc.  (whizzy-tikz-strip-trailing-zeros(format "%.10f" 1.2345))
    (strict . "\\(?:at *\\)?(\\(\\(?:-?[0-9.]+\\|\\),-?[0-9.]+\\))")
    ;; Lax can be used
    (lax    . "\\(?:at *\\)?(\\([()]+\\))")))

(defun whizzy-tikz-match (command name first line file type dx dy)
  (save-window-excursion
    (save-excursion
      (save-restriction
        ;; Find the file and go to the correct line
        (and (prog1 (whizzy-goto-file file)
               (widen))
             (goto-char (point-min))
             (prog1 (forward-line (1- (string-to-number line)))
               (beginning-of-line))

             ;; Try to minimize any damage we might do by accidentally
             ;; changing a tikz node far away from the current one.
             (whizzy-narrow-to-tikz)

             ;; The real work
             (let* (;; type orig x y xmid ymid
                    ;;  0    1   2 3  4    5
                    (pieces (split-string name "@"))
                    ;; tikz,matcher,precision,duplicate?
                    ;;   0 ,   1   ,    2    ,    3
                    (style-pieces (split-string (car pieces) ":"))
                    (precision (string-to-number (nth 2 style-pieces)))
                    (newx (+ (string-to-number (nth 4 pieces))
                             (- (string-to-number dx)
                                (string-to-number (nth 2 pieces)))))
                    (newy (+ (string-to-number (nth 5 pieces))
                             (- (string-to-number dy)
                                (string-to-number (nth 3 pieces)))))
                    ;; TODO: don't include trailing zeros? -- should I round instead?
                    (specifier (format "%%.%df,%%.%df" precision precision))
                    (replacement (format specifier newx newy))
                    ;; (regexp (aget whizzy-tikz-node-regexp 'lax))
                    (modified  (buffer-modified-p)))
               (dolist (regexp (list
                                ;; Check for an exact match
                                (concat "\\b\\(" (nth 1 pieces) "\\)\\b")
                                ;; Check for a fuzzy match -- this
                                ;; should actually depend on matcher
                                ;; in style-pieces.
                                (aget whizzy-tikz-node-regexp 'lax)))
                 ;; We should probably check how many there are and act accordingly
                 (when
                     ;; We start at the end of the line
                     (or (re-search-backward regexp (point-min) t)
                         (re-search-forward regexp (point-max) t))

                   ;; We found one -- replace it
                   (let ((edited
                          ;;  (save-match-data
                          ;;    (and (string= (match-string-no-properties 1) dx)
                          ;;         (string= (match-string-no-properties 2) dy))))
                          t)
                         (saved-line (and (string= "duplicate" (nth 3 style-pieces))
                                          (buffer-substring-no-properties
                                           (line-beginning-position)
                                           (line-end-position)))))
                     ;; Replace it
                     (replace-match replacement t t nil 1)
                     ;; "Duplicate" it -- putting the new copy _after_ the old
                     (when saved-line
                       (beginning-of-line)
                       (insert saved-line))
                     ;; rewhizzify
                     (unless (not edited)
                       (if (or modified
                               (equal (whizzy-get whizzy-active-buffer)
                                      (current-buffer)))
                           (whizzy-observe-changes)
                         (save-buffer)
                         (whizzy-reslice))))))))))))
