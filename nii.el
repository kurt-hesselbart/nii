;;; nii.el --- Jumping between (nearly instantly build) instances (i.e. a string or a regular expression).

;; Copyright (C) 2019 Kurt Hesselbart

;; Author: Kurt Hesselbart <kurt.hesselbart@gmail.com>
;; Version: 0.1
;; Package-Requires: ((emacs "25.2.2"))
;; Keywords: convenience
;; URL: https://github.com/kurt-hesselbart/nii

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; If you need to jump to specific strings or regexps regularly, you probably use standard search functions.
;; But it could be more convenient to jump independently of the standard search routine.

;; Perhaps you use occur, which has the disadvantage to act on lines not on true occurences.

;; An instance (in the manner of nii) is an occurence enhanced by a definition of the position of point after reaching the occurence.

;; After setting up a set of instances, described by strings or regular expressions,
;; you can choose shortly an instance for navigating similar to functions like ‘forward-paragraph’.

;; The word instances is used (in the documentation as well as in the names of the functions) to avoid the work occurrence,
;; which could mislead to think of a relationship to the occur functions.

;; The set of instances is arranged in an alist, where the key is the instance name.
;; The value has three elements.
;; The first element is a regular expression or a list which contains one or more strings representing the search item.
;; The second and third element represent information about the behaviour of point after reaching the item.

;; There is a bunch of functions helping to maintain the set of instances, see ‘nii-maintain-instances’.

;; You can set up the package like this:

;;     (require 'nii)
;;     (global-set-key (kbd "M-a") #'nii-forward-instance)
;;     (global-set-key (kbd "M-e") #'nii-backward-instance)
;;     (global-set-key (kbd "C-x M-a") #'nii-maintain-instances)

;; nii is written with the use of a completion framework (such as ido, ivy or helm) in mind,
;; so it could be less convenient to choose an instance without such a framework.

;; The user can use the customization tool to maintain the instances, but I prefer using ‘nii-maintain-instances’.

;; Per default the alist holding the instances will be saved to the custom.
;; It's recommended to use a distinct file by filling variable ‘nii-instances’.

;;; TODO:

;; Tthe variable holding the instances are stored to the custom.
;; It has been done, because it is available at every emacs configuration.
;; There should be a option to store to a distinct file.
;;
;; The pointer variable isn't stored between sessions.
;;
;; The editing of the strings means to reenter all strings from scratch, this isn't very comfortable.

;; nii works only in the current buffer, it should be possible to search in all buffers, or releated buffers.
;; projectile integration should be fine.

;;; Code:

(defgroup nii nil
  "Nearly instant instances for simpler navigation to typical places."
  :group 'convenience
  :prefix "nii-")

;; (defcustom nii-storage nil
;;   "Configuration file for storing the alist holding the instances.
;; If nil, the custom setting portion is used instead."
;;   :type '(choice (file :tag "Use configuration file")
;;                  (const :tag "Don't use distinct configuration file (nil)" nil)))

(defcustom nii-instances
  '(("TS-, CE- and Inotes" ("\\TSnote" "\\CEnote" "\\Inote") t nil)
    ("index and glossary entries" ("\\index{" "\\glosseintrag{" "\\glossnoidx{") t t))
  "An alist to hold instances for nii functions.
The first element (the key) is the name of the instance.

The second element is a regexp or a list of strings.

If the third element is nil, the position of point corresponds to the way
 of standard searches.

If the third element is non-nil and the fourth is nil,
 point is placed always at the beginning of the instance.

If the third and fourth element is non-nil,
 point is placed always at the end of the instance."
  :type '(alist
          :key-type
          (string :tag "Name")
          :value-type
          (group
           (choice :tag "Choose: Regexp or string(s)"
            (regexp :tag "Regexp")
            (repeat :tag "String(s)" (string)))
           (boolean :tag "Adjust point position")
           (boolean :tag "Point position at the end of string"))))

(defvar nii-instance-pointer nil
  "The current instance used for nii functions.")

(defvar nii-create-instance-name-history nil
  "History for instances names for the hop functions.")

(defvar nii-create-instance-regexp-history nil
  "History for instances regexp values for the hop functions.")

(defvar nii-create-instance-string-history nil
  "History for instances string values for the hop functions.")

;;;###autoload
(defun nii-maintain-instances ()
  "Maintain the instances.

There can only be one active instance.

You can choose this active instance of the existing ones,
 or you can create a new instance,
 or edit or delete an existing instance.

It's very recommended to use a completion framework (such as ido, ivy or helm).
Otherwise the function is pretty inconvenient to use."
  (interactive)
  (let (*choice*
        (*options* '(("Choose an existing instance")
                     ("Create a new instance")
                     ("Edit an existing instance")
                     ("Delete an existing instance"))))
    (setq *choice* (completing-read "Choose an action for the hop functions: " *options* nil t))
    (cond
     ((equal *choice* "Choose an existing instance")
      (nii-choose-current-instance))
     ((equal *choice* "Create a new instance")
      (nii-create-instance))
     ((equal *choice* "Edit an existing instance")
      (nii-edit-instance))
     ((equal *choice* "Delete an existing instance")
      (nii-delete-instance)))))

;;;###autoload
(defun nii-choose-current-instance ()
  "Choose one of the preconfigured instances.
Set the choice as the actuve instance.

There can only be one active instance.

It's very recommended to use a completion framework (such as ido, ivy or helm).
Otherwise the function is pretty inconvenient to use."
  (interactive)
  (nii--set-current-instance (completing-read "Choose a prepared instance: " nii-instances nil t)))

(defun nii--set-current-instance (instance)
  "Set the choice as the active INSTANCE.

There can only be one active instance."
  (if (assoc instance nii-instances)
      (setq nii-instance-pointer instance)
    (error "There is no key named %s in the nii-instances" instance)))

(defun nii--store-instances ()
  "Store the instances to the configured place."
  (let ((inhibit-message t)
        (message-log-max nil))
    (customize-save-variable 'nii-instances nii-instances (format "Changed at %s" (format-time-string "%Y-%m-%d %H:%M:%S")))))

;;;###autoload
(defun nii-create-instance ()
  "Create a new instance.

These are the options:

1. A proper name for the instance.
2. One regular expression or one string or multiple strings.
3. The behaviour in respect of the location of point
   after reaching the search item.

It's very recommended to use a completion framework (such as ido, ivy or helm).
Otherwise the function is pretty inconvenient to use."
  (interactive)
  (catch 'edit-existing-instance
    (let
        (*instance-name*
         *instance-regexp-or-strings*
         *instance-element*
         *instance-abberrate*
         *instance-end*)

      ;; Choose new name, prevent a duplicate.
      (while (not *instance-name*)
        (setq *instance-name* (read-string "Provide a name for the new instance: " nil 'nii-create-instance-name-history))
        (when (assoc *instance-name* nii-instances)
          (if
              (y-or-n-p (format "»%s« is already in use, do you want to edit this instance? " *instance-name*))
              (progn
                (nii-edit-instance *instance-name*)
                (throw 'edit-existing-instance 't))
            (setq *instance-name* nil))))

      ;; Choose between string and regexp.
      (setq *instance-regexp-or-strings*
            (completing-read "You can use one regular expression or one string or multiple strings as instance. Please choose: " '("one regular expression" "one string or multiple strings") nil t))

      (cond
       ;; Regexp input.
       ((equal *instance-regexp-or-strings* "one regular expression")
        (setq *instance-element* (nii--edit-regexp nil)))

        ;; String input.
       ((equal *instance-regexp-or-strings* "one string or multiple strings")
        (setq *instance-element* (nii--edit-strings))))

      ;; Options input.
      (when
          (setq *instance-abberrate* (not (y-or-n-p "Do you want the standard isearch behaviour with respect to the place of point after the search? ")))
        (setq *instance-end* (y-or-n-p "Do you want point being always at the end of the search result? ")))

      ;; Add new instance to variable.
      (add-to-list 'nii-instances (list *instance-name* *instance-element* *instance-abberrate* *instance-end*) t)

      ;; Store the variable permanently.
      (nii--store-instances)

      ;; Inform the user.
      (message "The new instance »%s« was added to the list of instances for the hop functions." *instance-name*))))

;;;###autoload
(defun nii-edit-instance (&optional instance)
  "Edit an existing INSTANCE.

These are the options:

1. A proper name for the instance.
2. One regular expression or one string or multiple strings.
3. The behaviour in respect of the location of point
   after reaching the search item.

It's very recommended to use a completion framework (such as ido, ivy or helm).
Otherwise the function is pretty inconvenient to use."
  (interactive)
  (unless instance
    (setq instance (nii--set-current-instance (completing-read "Which instance do you want to edit? " nii-instances nil t))))
  (let* ((*old-instance-name* instance)
         (*old-instance-values* (cdr (assoc *old-instance-name* nii-instances)))
         (*old-instance-regexp-or-strings* (pop *old-instance-values*))
         *old-instance-regexp*
         *old-instance-string*
         *old-instance-strings-string*
         *new-instance-name*
         *new-instance-element*
         *new-instance-abberrate*
         *new-instance-end*)

    ;; Check for strings and create a readable string of strings.
    (if (listp *old-instance-regexp-or-strings*)
        (progn
          (setq *old-instance-strings-string* (mapconcat 'identity *old-instance-regexp-or-strings* ", "))
          (setq *old-instance-string* *old-instance-regexp-or-strings*))
      (setq *old-instance-regexp* *old-instance-regexp-or-strings*))

    ;; Change name?
    (if
        (y-or-n-p (format "Do you want to change the name »%s«? " *old-instance-name*))
        (setq *new-instance-name* (read-string (format "Change the name of the instance »%s«: " *old-instance-name*) *old-instance-name* 'nii-create-instance-name-history))
      (setq *new-instance-name* *old-instance-name*))

    (while (and (not (equal *new-instance-name* *old-instance-name*))
                (assoc *new-instance-name* nii-instances))
      (setq *new-instance-name* (read-string (format "Change the name of the instance »%s«: " *new-instance-name*) *new-instance-name* 'nii-create-instance-name-history)))

    ;; Is it string or regexp?
    (if *old-instance-regexp*

        ;; Change regexp?
        (let (*choice*
              (*options* '(("Keep the regular expression.")
                           ("Edit the regular expression.")
                           ("Use a string or multiple strings instead."))))
          (setq *choice* (completing-read (format "Do you want to change the regular expression »%s«? " *old-instance-regexp*) *options* nil t nil nil "Keep the regular expression."))
          (cond
           ((equal *choice* "Keep the regular expression.")
            (setq *new-instance-element* *old-instance-regexp*))
           ((equal *choice* "Edit the regular expression.")
            (setq *new-instance-element* (nii--edit-regexp *old-instance-regexp*)))
           ((equal *choice* "Use a string or multiple strings instead.")
            (setq *new-instance-element* (nii--edit-strings)))))

      ;; Change string?
      (let (*choice*
            (*options* '(("Keep the string(s).")
                         ("Edit the string(s), which means to reenter all strings!")
                         ("Use a regular expression instead."))))
        (setq *choice* (completing-read (format "Do you want to change the string(s) »%s«? " *old-instance-strings-string*) *options* nil t nil nil "Keep the string(s)."))
        (cond
         ((equal *choice* "Keep the string(s).")
          (setq *new-instance-element* *old-instance-string*))
         ((equal *choice* "Edit the string(s), which means to reenter all strings!")
          (setq *new-instance-element* (nii--edit-strings)))
         ((equal *choice* "Use a regular expression instead.")
          (setq *new-instance-element* (nii--edit-regexp))))))

    ;; Options input.
    (when
        (setq *new-instance-abberrate* (not (y-or-n-p "Do you want the standard isearch behaviour with respect to the place of point after the search? ")))
      (setq *new-instance-end* (y-or-n-p "Do you want point being always at the end of the search result? ")))

    ;; Add new instance.
    (if (equal *new-instance-name* *old-instance-name*)
        (setf (cdr (assoc *old-instance-name* nii-instances)) (list *new-instance-element* *new-instance-abberrate* *new-instance-end*))
      (setf (cdr (assoc *old-instance-name* nii-instances)) (list *new-instance-element* *new-instance-abberrate* *new-instance-end*))
      (setf (car (assoc *old-instance-name* nii-instances)) *new-instance-name*))

    ;; Store the variable permanently.
    (nii--store-instances)

    ;; Inform the user.
    (message "The edit of instance »%s« has been finished." *new-instance-name*)))

;;;###autoload
(defun nii-delete-instance (&optional instance)
  "Delete an existing INSTANCE.

It's very recommended to use a completion framework (such as ido, ivy or helm).
Otherwise the function is pretty inconvenient to use."
  (interactive)
  (when
      (or (not instance)
          (not (assoc instance nii-instances)))
    (setq instance (nii--set-current-instance (completing-read "Which instance do you want to delete? " nii-instances nil t))))

  (when (yes-or-no-p (format "Do you really want to delete the instance »%s«? " instance))
    ;; Delete the instance.
    (nii--assoc-delete-all instance nii-instances)

    ;; Store the variable permanently.
    (nii--store-instances)

    ;; Inform the user.
    (message "The deletion of instance »%s« has been finished." instance)))

(defun nii--edit-regexp (&optional regexp)
  "Return a REGEXP for creating or editing nii instances."
  (read-regexp "Provide a regular expression for the instance: " regexp 'nii-create-instance-regexp-history))

(defun nii--edit-strings ()
  "Return a list of strings for creating or editing nii instances."
  (let (*strings-number*
        *strings-string*
        *string*
        *element*)
    (setq *string* (read-string "Provide a string for the instance: " nil 'nii-create-instance-string-history))
    (while (equal *string* "")
      (setq *string* (read-string "You must provide at least one string for the instance: " nil 'nii-create-instance-string-history)))
    (setq *element* (list *string*))
    (setq *strings-string* *string*)

    (while (not (equal *string* ""))
      (setq *string* (read-string
                      (format "You provided: »%s«.\nAdd another string (or return for no further string): " *strings-string*)
                      nil 'nii-create-instance-string-history))
      (when (not (equal *string* ""))
        (push *string* *element*)
        (setq *strings-string* (concat *strings-string* ", " *string*))))
    (setq *element* (delete-dups *element*))))

;;;###autoload
(defun nii-forward-instance (&optional arg)
  "Move forward to next instance.
With argument ARG, do it that often.
A negative value of ARG moves backwards that often.

An instance is a regular expression (optionally compound with strings),
 including an definition, where point should be located
 after reaching the searched item.

If there is no active instance, you will be asked to choose
 an entry from ‘nii-instances’.

To change the current instance, run ‘nii-choose-current-instance’.

To create a new entry, you can run ‘nii-create-instance’.
To edit an existing entry, you can run ‘nii-edit-instance’.
To delete an existing entry, you can run ‘nii-delete-instance’.

All these functions you can also reach by ‘nii-maintain-instances’."
  (interactive "^p")
  (let (*instances-count*
        *instance-name*
        *instance-regexp*
        *instance-abberrate*
        *instance-end*
        *instance-values*
        *looking-back-limit*)

    ;; If there is no or no available active instance, the user should choose one.
    (when
        (or (not nii-instance-pointer)
            (not (assoc nii-instance-pointer nii-instances)))
      (nii-choose-current-instance))

    ;; Use the values of the current instance.
    (setq *instance-name* nii-instance-pointer)
    (setq *instance-values* (cdr (assoc nii-instance-pointer nii-instances)))
    (setq *instance-regexp* (pop *instance-values*))
    ;; If a list is provided, it must be a list of strings, which is transformed to an regexp.
    (when (listp *instance-regexp*)
      (setq *instance-regexp* (regexp-opt *instance-regexp*)))

    ;; The default behaviour is identical to isearch:
    ;; At forward search, point will be at the end of the string,
    ;; at backward search, point will be at the beginning of the string,
    ;; but the user can manipulate this behaviour.
    (and (setq *instance-abberrate* (pop *instance-values*))
         (setq *instance-end* (pop *instance-values*)))

    ;; We do not we to interfere with other searches.
    (save-match-data
      ;; If no argument is given, we will forward 1 instance.
      (or arg (setq arg 1))

      ;; Check the argument.
      (cond

       ;; Forward.
       ((> arg 0)
        ;; If option is active, where point should always end at the beginning of the string and
        ;; if point is directly at an instance, we have to search for the next but one.
        (when (and *instance-abberrate* (not *instance-end*))
          (when (looking-at *instance-regexp*) (setq arg (+ arg 1))))

        ;; Is there a next instance?
        (if (search-forward-regexp *instance-regexp* nil t arg)

            ;; There is a next instance.
            (progn
              ;; Shall I jump to the beginning of the instance?
              (nii--instances-cursor-placement *instance-abberrate* *instance-end*)

              ;; Inform the user.
              (setq *instances-count* (nii--instances-count *instance-regexp*))
              (message
               (format "Hop instance »%s« (%s/%s) in the current buffer."
                       *instance-name*
                       (number-to-string (car *instances-count*))
                       (number-to-string (cdr *instances-count*)))))

          ;; No, there is no next instance.
          (setq *instances-count* (nii--instances-count *instance-regexp*))

          ;; Helper to speed up looking-back.
          (when (< (setq *looking-back-limit* (- (point) 100)) 1)
            (setq *looking-back-limit* (point-min)))
          ;; Are we at the last instance?
          (if (if (or (not *instance-abberrate*) *instance-end*)
                  (looking-back *instance-regexp* *looking-back-limit*)
                (looking-at *instance-regexp*))

              ;; Yes, we are at the last instance.
              ;; Inform the user.
              (message
               (format "Hop instance »%s« (%s/%s): This is the last instance in the current buffer."
                       *instance-name*
                       (number-to-string (car *instances-count*))
                       (number-to-string (cdr *instances-count*))))

            ;; No, we are not at the last instance.
            ;; Inform the user.
            (message
             (format "Hop instances »%s« (%s): There is no next instance in the current buffer."
                     *instance-name*
                     (number-to-string (cdr *instances-count*)))))))

       ;; Backward.
       ((< arg 0)
        ;; Helper to speed up looking-back.
        (when (< (setq *looking-back-limit* (- (point) 100)) 1)
          (setq *looking-back-limit* (point-min)))
        ;; If point is directly at an instance, we have to search for the next but one.
        (when *instance-end*
          (when (looking-back *instance-regexp* *looking-back-limit*) (setq arg (- arg 1))))

        ;; Is there a previous instance?
        (if (search-forward-regexp *instance-regexp* nil t arg)

            ;; There is a previous instance.
            (progn
              ;; Shall I jump to the beginning of the instance?
              (nii--instances-cursor-placement *instance-abberrate* *instance-end*)

              ;; Inform the user.
              (setq *instances-count* (nii--instances-count *instance-regexp*))
              (message
               (format "Hop instance »%s« (%s/%s) in the current buffer."
                       *instance-name*
                       (number-to-string (car *instances-count*))
                       (number-to-string (cdr *instances-count*)))))

          ;; There is no previous instance.
          (progn
            (setq *instances-count* (nii--instances-count *instance-regexp*))

            ;; Do we are at the first instance?
            (when (< (setq *looking-back-limit* (- (point) 100)) 1)
              (setq *looking-back-limit* (point-min)))
            (if (if *instance-end*
                    (looking-back *instance-regexp* *looking-back-limit*)
                  (looking-at *instance-regexp*))

                ;; Yes, we look at the first instance.
                ;; Inform the user.
                (message
                 (format "Hop instance »%s« (%s/%s): This is the first instance in the current buffer."
                         *instance-name*
                         (number-to-string (car *instances-count*))
                         (number-to-string (cdr *instances-count*))))

              ;; No, we do not look at the first instance.
              ;; Inform the user.
              (message
               (format "Hop instances »%s« (%s): There is no previous instance in the current buffer."
                       *instance-name*
                       (number-to-string (cdr *instances-count*))))))))))))

;;;###autoload
(defun nii-backward-instance (&optional arg)
  "Move backward to previous instance.
With argument ARG, do it that often.
A negative value of ARG moves forwards that often.

An instance is a string or a regular expression,
 including an definition, where point should be located
 after reaching the searched item.

If there is no active instance, you will be asked to choose
 an entry from ‘nii-instances’.

To change the current instance, run ‘nii-choose-current-instance’.

To create a new entry, you can run ‘nii-create-instance’.
To edit an existing entry, you can run ‘nii-edit-instance’.
To delete an existing entry, you can run ‘nii-delete-instance’.

All these functions you can also reach by ‘nii-maintain-instances’."
  (interactive "^p")
  (nii-forward-instance (- arg)))

(defun nii--instances-count (regexp)
  "Return a cons list of the number of REGEXP.
The car tells the number from point on,
 the cdr tells the total number."
  (let (*instances-all*
        *instance-at-point*)
    (setq *instances-all* (count-matches regexp (point-min) (point-max)))
    (setq *instance-at-point* (count-matches regexp (point-min) (point)))
    (when (looking-at regexp) (setq *instance-at-point* (+ 1 *instance-at-point*)))
    (cons *instance-at-point* *instances-all*)))

(defun nii--instances-cursor-placement (abberate end)
  "Place point if necessary.
If ABBERATE is non-nil, point has to be replaced.
If END is nil, point is always at the front of the search item,
if END in non-nil, point is placed at the end of the search item."
  (when abberate
    (if end
        (goto-char (match-end 0))
      (goto-char (match-beginning 0)))))

;; The function ‘assoc-delete-all’ is part of more recent versions of emacs, but at this very moment I have to use emacs 25.2.2, which doesn't provide this function.
;; Therefore I made this copy of the function.
(defun nii--assoc-delete-all (key alist &optional test)
  "Delete from ALIST all elements whose car is KEY.
Compare keys with TEST.  Defaults to `equal'.
Return the modified alist.
Elements of ALIST that are not conses are ignored."
  (unless test (setq test #'equal))
  (while (and (consp (car alist))
              (funcall test (caar alist) key))
    (setq alist (cdr alist)))
  (let ((tail alist) tail-cdr)
    (while (setq tail-cdr (cdr tail))
      (if (and (consp (car tail-cdr))
               (funcall test (caar tail-cdr) key))
          (setcdr tail (cdr tail-cdr))
        (setq tail tail-cdr))))
  alist)

(provide 'nii)

;;; nii.el ends here
