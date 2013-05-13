;;;
;;; AlbLaTeX/lisp/alb-latex-interpret.el
;;;
;;;     Copyright (C) 2000-2003, 2013 Andrew Lincoln Burrow
;;;
;;;     This library is free software; you can redistribute it and/or
;;;     modify it under the terms of the GNU General Public License as
;;;     published by the Free Software Foundation; either version 2 of
;;;     the License, or (at your option) any later version.
;;;
;;;     This library is distributed in the hope that it will be useful,
;;;     but WITHOUT ANY WARRANTY; without even the implied warranty of
;;;     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;;     GNU General Public License for more details.
;;;
;;;     You should have received a copy of the GNU General Public
;;;     License along with this library; if not, write to the Free
;;;     Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
;;;     MA 02111-1307, USA.
;;;
;;;   - Functions to interpret parse trees yielded by the
;;;     `alb-LaTeX-parse-*' functions.
;;;
;;;   - The interpreter traverses the parse tree whilst collecting a
;;;     single value: the file list.  This is a possibly incomplete list
;;;     of visited files.  The first element is always the master
;;;     filename, the second element is always the current filename, but
;;;     other filenames need not be passed in the list.  All other
;;;     actions are performed as side effects of this traversal.
;;;
;;;   - The interpreter is composed of mutually recursive functions: the
;;;     `alb-LaTeX-interpret' function recurs on the elements of a parse
;;;     tree forest, as generated by an `alb-LaTeX-collect-*' function;
;;;     while functions named `alb-LaTeX-interpret-*' process single
;;;     parse trees as generated by an `alb-LaTeX-parse-*' function.
;;;
;;;     The two forms are related by a context argument, which is used
;;;     to associate parse trees with specialised interpreter functions.
;;;     Thus, the basic interpreter can be extended to interpret
;;;     particular forms.
;;;
;;;   - Example: the interpreter in "alb-graphicx.el" generates a
;;;     sequence of LaTeX source files by progressive updates to the
;;;     current buffer.  The files are used to generate PDF versions of
;;;     PSfragged EPS graphics.  The filelist is used to transmit a
;;;     dependency list for the current buffer state, and the buffer is
;;;     compiled only when the target is older than a file on the
;;;     dependency list.
;;;



;;; *** PROVIDED FEATURE ******************************************************


(provide 'alb-latex-interpret)



;;; *** REQUIRED FEATURES *****************************************************



;;; *** VARIABLE DECLARATIONS *************************************************


(defvar alb-LaTeX-interpreter-context-standard
  '(("alb-LaTeX-parse-inclusion"
     . alb-LaTeX-interpret-inclusion)
    ("alb-LaTeX-parse-document-environment"
     . alb-LaTeX-interpret-document-environment))
  "Minimum LaTeX interpreter context to handle document environment and
file input.  Most interpreter contexts should extend this standard
context.

For a more detailed description see: `alb-LaTeX-interpret'.")



;;; *** FUNCTION DEFINITIONS **************************************************


(defun alb-LaTeX-interpret (context forest filelist)
  "Traverse the forest of parse subtrees in FOREST and apply specialised
interpreters via the alist CONTEXT.  Return the filelist accumulated by
these interpreters above FILELIST.

CONTEXT is an alist controlling the behaviour of the interpreter.  The
value of CONTEXT maps parse trees into specialised interpreters.  Parse
trees are recognised by their `car', e.g., see description of parse tree
returned by `alb-LaTeX-parse-inclusion'.  Specialised interpreters
accept the same arguments except that FOREST is replaced by TREE which
refers to a single parse tree, as returned by an `alb-LaTeX-parse-*'
function.  See `alb-LaTeX-interpreter-context-standard' for the builtin
interpreters.

FOREST is a possibly empty list of parse trees as returned by an
`alb-LaTeX-collect-*' function.

FILELIST is a non-empty list of filenames.  The first filename refers to
the master file of the parsed LaTeX source, and the second filename
refers to the source of the last parse tree.  The remainder of the list
is a possibly empty stack of filenames, where the car is the top of
stack.  The list is initialized by the
`alb-LaTeX-interpret-document-environment' function."
  (let* ((head (car-safe forest))
         (tail (cdr-safe forest))
         (rule (cdr-safe (assoc (car-safe head) context))))
    (cond
     ((null head)
      ;; Base case: return the current filelist.
      filelist)
     ((null rule)
      ;; No specialised interpreter: skip the parse tree.
      (alb-LaTeX-interpret
       context tail filelist))
     (t
      ;; Specialised interpreter: recur on the tail of the forest using the
      ;; file list from the specialised interpreter.
      (alb-LaTeX-interpret
       context tail (apply rule (list context head filelist)))))))



(defun alb-LaTeX-interpret-inclusion (context tree filelist)
  "Interpret TREE as a parse tree generated by
`alb-LaTeX-parse-inclusion'.  Replace the second element in FILELIST
with the subject of TREE and interpret the result from TREE.  Return the
first and second elements of FILELIST prepended to the stack returned by
interpreting the result, i.e., do not record the subject as the current
file except during interpretation of the subtrees.

CONTEXT maps parse subtree names to interpreters.
TREE is a parse tree as returned by an `alb-LaTeX-parse-*' function.
FILELIST is a non-empty list of filenames.  See `alb-LaTeX-interpret'.

See `alb-LaTeX-interpret' for further details.  This function is called
by `alb-LaTeX-interpret' if in CONTEXT's range."
  (let* ((parse (cdr tree))
         (master-name (car filelist))
         (old-fname (cadr filelist))
         (new-fname (cdr (assoc "enter" parse)))
         (branch-forest (cdr (assoc "result" parse))))
    (append (list master-name old-fname)
            (cddr (alb-LaTeX-interpret
                   context branch-forest (append (list master-name new-fname)
                                                 (cddr filelist)))))))



(defun alb-LaTeX-interpret-document-environment (context tree filelist)
  "Interpret TREE as a parse tree generated by
`alb-LaTeX-parse-document-environment'.  Replace FILELIST with the list
containing two copies of the subject of TREE and interpret the result
from TREE, i.e., set the subject of TREE to the master and current file
in FILELIST.

CONTEXT maps parse subtree names to interpreters.
TREE is a parse tree as returned by an `alb-LaTeX-parse-*' function.
FILELIST is a non-empty list of filenames.  See `alb-LaTeX-interpret'.

See `alb-LaTeX-interpret' for further details.  This function is called
by `alb-LaTeX-interpret' if in CONTEXT's range."
  (let* ((parse (cdr tree))
         (master-name (cdr (assoc "master" parse)))
         (branch-forest (cdr (assoc "result" parse))))
    (alb-LaTeX-interpret
     context branch-forest (list master-name master-name))))



;;; Local Variables:
;;; mode: emacs-lisp
;;; End:
