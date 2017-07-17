
;; This table omits anything that the expander implements itself,
;; since the expander will export its own variant nistead of the
;; `kernel-table` variant.

(define kernel-table
  (make-primitive-table
   *
   +
   -
   /
   <
   <=
   =
   >
   >=
   quotient
   quotient/remainder
   remainder
   abort-current-continuation
   abs
   absolute-path?
   add1
   acos
   alarm-evt
   always-evt
   andmap
   angle
   append
   apply
   arithmetic-shift
   asin
   assoc
   assq
   assv
   atan
   banner
   bitwise-and
   bitwise-bit-set?
   bitwise-bit-field
   bitwise-ior
   bitwise-not
   bitwise-xor
   boolean?
   bound-identifier=?
   box
   box-cas!
   box-immutable
   box?
   break-enabled
   break-thread
   build-path
   build-path/convention-type
   byte-ready?
   byte-pregexp
   byte-pregexp?
   byte-regexp
   byte-regexp?
   byte?
   bytes
   bytes->immutable-bytes
   bytes->list
   bytes->path
   bytes->path-element
   bytes->string/latin-1
   bytes->string/locale
   bytes->string/utf-8
   bytes-append
   bytes-close-converter
   bytes-convert
   bytes-convert-end
   bytes-converter?
   bytes-copy
   bytes-copy!
   bytes-fill!
   bytes-length
   bytes-open-converter
   bytes-ref
   bytes-set!
   bytes-utf-8-index
   bytes-utf-8-length
   bytes-utf-8-ref
   bytes>?
   bytes<?
   bytes=?
   bytes<=?
   bytes>=?
   bytes?
   caadr
   call-in-nested-thread
   call-with-composable-continuation
   call-with-continuation-barrier
   call-with-continuation-prompt
   call-with-current-continuation
   call-with-escape-continuation
   call-with-immediate-continuation-mark
   call-with-input-file
   call-with-output-file
   call-with-semaphore
   call-with-semaphore/enable-break
   call-with-values
   ceiling
   channel?
   channel-put-evt
   channel-put-evt?
   chaperone?
   chaperone-of?
   chaperone-box
   chaperone-continuation-mark-key
   chaperone-channel
   chaperone-evt
   chaperone-hash
   chaperone-procedure
   chaperone-procedure*
   chaperone-prompt-tag
   chaperone-struct
   chaperone-struct-type
   chaperone-vector
   chaperone-vector*
   char->integer
   char-alphabetic?
   char-downcase
   char-foldcase
   char-general-category
   char-graphic?
   char-blank?
   char-iso-control?
   char-numeric?
   char-ready?
   char-lower-case?
   char-punctuation?
   char-symbolic?
   char-title-case?
   char-upper-case?
   char-upcase
   char-titlecase
   char-whitespace?
   char-utf-8-length
   char<=?
   char<?
   char=?
   char>=?
   char>?
   char?
   char-ci<=?
   char-ci<?
   char-ci=?
   char-ci>=?
   char-ci>?
   ;; char-utf-8-length
   checked-procedure-check-and-extract
   choice-evt
   cleanse-path
   close-input-port
   close-output-port
   collect-garbage
   compile
   complex?
   compile-allow-set!-undefined
   compile-enforce-module-constants
   compile-context-preservation-enabled
   complete-path?
   continuation-marks
   continuation-mark-key?
   continuation-mark-set?
   continuation-mark-set-first
   continuation-mark-set->list
   continuation-mark-set->list*
   continuation-mark-set->context
   continuation-prompt-available?
   continuation-prompt-tag?
   continuation?
   copy-file
   cos
   current-code-inspector
   current-command-line-arguments
   current-continuation-marks
   current-custodian
   current-directory
   current-directory-for-user
   current-drive
   current-environment-variables
   current-error-port
   current-evt-pseudo-random-generator
   current-force-delete-permissions
   current-gc-milliseconds
   current-get-interaction-input-port
   current-inexact-milliseconds
   current-input-port
   current-inspector
   current-load-extension
   current-load-relative-directory
   current-locale
   current-logger
   current-memory-use
   current-milliseconds
   current-output-port
   current-plumber
   current-preserved-thread-cell-values
   current-print
   current-process-milliseconds
   current-prompt-read
   current-pseudo-random-generator
   current-read-interaction
   current-seconds
   current-security-guard
   current-subprocess-custodian-mode
   current-thread
   current-thread-group
   current-thread-initial-stack-size
   current-write-relative-directory
   custodian?
   custodian-box?
   custodian-box-value
   custodian-limit-memory
   custodian-managed-list
   custodian-memory-accounting-available?
   custodian-require-memory
   custodian-shutdown-all
   custom-print-quotable?
   custom-print-quotable-accessor
   custom-write?
   custom-write-accessor
   datum-intern-literal
   default-continuation-prompt-tag
   delete-directory
   delete-file
   denominator
   directory-exists?
   directory-list
   display
   double-flonum?
   dump-memory-stats
   dynamic-wind
   environment-variables-ref
   environment-variables-set!
   environment-variables-copy
   environment-variables-names
   environment-variables?
   eof
   eof-object?
   ephemeron?
   ephemeron-value
   eprintf
   eq-hash-code
   eq?
   equal-hash-code
   equal-secondary-hash-code
   equal?
   equal?/recur
   eqv?
   eqv-hash-code
   error
   error-display-handler
   error-escape-handler
   error-print-context-length
   error-print-source-location
   error-print-width
   error-value->string-handler
   eval-jit-enabled
   even?
   evt?
   exact-integer?
   exact-nonnegative-integer?
   exact-positive-integer?
   exact?
   exact->inexact
   executable-yield-handler
   exit
   exit-handler
   exn-continuation-marks
   exn-message
   exn?
   expand-user-path
   exp
   explode-path
   expt
   file-exists?
   file-or-directory-modify-seconds
   file-or-directory-identity
   file-or-directory-permissions
   file-position
   file-position*
   file-size
   file-stream-buffer-mode
   file-stream-port?
   file-truncate
   filesystem-change-evt
   filesystem-change-evt?
   filesystem-change-evt-cancel
   filesystem-root-list
   find-system-path
   fixnum?
   flonum?
   floor
   floating-point-bytes->real
   flush-output
   for-each
   format
   fprintf
   gcd
   gensym
   get-output-bytes
   get-output-string
   global-port-print-handler
   handle-evt
   handle-evt?
   hash
   hash-clear
   hash-clear!
   hash-copy
   hash-count
   hash-eq?
   hash-eqv?
   hash-equal?
   hash-for-each
   hash-iterate-first
   hash-iterate-key
   hash-iterate-key+value
   hash-iterate-next
   hash-iterate-pair
   hash-iterate-value
   hash-keys-subset?
   hash-map
   hash-placeholder?
   hash-ref
   hash-remove
   hash-remove!
   hash-set
   hash-set!
   hash-weak?
   hash?
   hasheq
   hasheqv
   imag-part
   immutable?
   impersonate-box
   impersonate-channel
   impersonate-continuation-mark-key
   impersonate-hash
   impersonate-procedure
   impersonate-procedure*
   impersonate-prompt-tag
   impersonate-struct
   impersonate-vector
   impersonate-vector*
   impersonator?
   impersonator-ephemeron
   impersonator-of?
   impersonator-property?
   impersonator-prop:application-mark
   impersonator-property-accessor-procedure?
   inexact?
   inexact-real?
   inexact->exact
   input-port?
   inspector-superior?
   inspector?
   integer->char
   integer->integer-bytes
   integer-bytes->integer
   integer-length
   integer-sqrt
   integer-sqrt/remainder
   integer?
   interned-char?
   kill-thread
   lcm
   length
   link-exists?
   list
   list*
   list->bytes
   list->string
   list->vector
   list-ref
   list-tail
   list?
   list-pair?
   load-on-demand-enabled
   locale-string-encoding
   log
   logger?
   logger-name
   log-all-levels
   log-level?
   log-level-evt
   log-max-level
   log-message
   log-receiver?
   magnitude
   make-bytes
   make-channel
   make-continuation-mark-key
   make-continuation-prompt-tag
   make-custodian
   make-custodian-box
   make-derived-parameter
   make-directory
   make-environment-variables
   make-ephemeron
   make-file-or-directory-link
   make-hash
   make-hash-placeholder
   make-hasheq
   make-hasheq-placeholder
   make-hasheqv
   make-hasheqv-placeholder
   make-input-port
   make-immutable-hash
   make-immutable-hasheq
   make-immutable-hasheqv
   make-impersonator-property
   make-inspector
   make-known-char-range-list
   make-logger
   make-log-receiver
   make-output-port
   make-parameter
   make-phantom-bytes
   make-pipe
   make-placeholder
   make-plumber
   make-polar
   make-prefab-struct
   make-pseudo-random-generator
   make-reader-graph
   make-rectangular
   make-security-guard
   make-semaphore
   make-shared-bytes
   make-sibling-inspector
   make-string
   make-struct-field-accessor
   make-struct-field-mutator
   make-struct-type
   make-struct-type-property
   make-thread-cell
   make-thread-group
   make-vector
   make-weak-box
   make-weak-hash
   make-weak-hasheq
   make-weak-hasheqv
   make-will-executor
   map
   max
   min
   modulo
   nack-guard-evt
   negative?
   never-evt
   newline
   not
   null
   null?
   number->string
   number?
   numerator
   object-name
   odd?
   open-input-bytes
   open-input-file
   open-input-output-file
   open-input-string
   open-output-bytes
   open-output-file
   open-output-string
   ormap
   output-port?
   parameter?
   parameter-procedure=?
   parameterization?
   path->bytes
   path->complete-path
   path->directory-path
   path->string
   path-convention-type
   path-element->bytes
   path-element->string
   path-for-some-system?
   path?
   path<?
   peek-byte
   peek-byte-or-special
   peek-bytes
   peek-bytes!
   peek-bytes-avail!
   peek-bytes-avail!*
   peek-bytes-avail!/enable-break
   peek-char-or-special
   peek-char
   peek-string
   peek-string!
   phantom-bytes?
   pipe-content-length
   placeholder?
   placeholder-get
   placeholder-set!
   plumber-add-flush!
   plumber-flush-all
   plumber-flush-handle-remove!
   plumber-flush-handle?
   plumber?
   poll-guard-evt
   port-closed?
   port-closed-evt
   port-commit-peeked
   port-count-lines!
   port-count-lines-enabled
   port-counts-lines?
   port-file-identity
   port-file-unlock
   port-next-location
   port-display-handler
   port-print-handler
   port-progress-evt
   port-provides-progress-evts?
   port-read-handler
   set-port-next-location!
   port-try-file-lock?
   port-write-handler
   port-writes-atomic?
   port-writes-special?
   positive?
   prefab-key->struct-type
   prefab-key?
   prefab-struct-key
   pregexp
   pregexp?
   primitive-table
   primitive?
   primitive-closure?
   primitive-result-arity
   printf
   print
   print-as-expression
   print-boolean-long-form
   print-box
   print-graph
   print-hash-table
   print-mpair-curly-braces
   print-pair-curly-braces
   print-reader-abbreviations
   print-struct
   print-syntax-width
   print-vector-length
   print-unreadable
   procedure-arity
   procedure-arity?
   procedure-arity-includes?
   procedure-extract-target
   procedure-impersonator*?
   procedure-reduce-arity
   procedure-rename
   procedure-result-arity
   procedure->method
   procedure?
   procedure-specialize
   procedure-struct-type?
   procedure-closure-contents-eq?
   progress-evt?
   prop:arity-string
   prop:authentic
   prop:checked-procedure
   prop:custom-print-quotable
   prop:custom-write
   prop:equal+hash
   prop:evt
   prop:impersonator-of
   prop:incomplete-arity
   prop:method-arity-error
   prop:procedure
   prop:object-name
   prop:output-port
   prop:input-port
   pseudo-random-generator?
   pseudo-random-generator->vector
   pseudo-random-generator-vector?
   random
   random-seed
   raise
   raise-user-error
   rational?
   read-accept-bar-quote
   read-byte
   read-byte-or-special
   read-bytes
   read-bytes!
   read-bytes-avail!
   read-bytes-avail!*
   read-bytes-avail!/enable-break
   read-bytes-line
   read-case-sensitive
   read-char
   read-char-or-special
   read-decimal-as-inexact
   read-line
   read-on-demand-source
   read-string
   read-string!
   real?
   real-part
   real->double-flonum
   real->floating-point-bytes
   real->single-flonum
   regexp
   regexp-match
   regexp-match/end
   regexp-match-positions
   regexp-match-positions/end
   regexp-match-peek
   regexp-match-peek-immediate
   regexp-match-peek-positions
   regexp-match-peek-positions/end
   regexp-match-peek-positions-immediate
   regexp-match-peek-positions-immediate/end
   regexp-match?
   regexp-max-lookbehind
   regexp-replace
   regexp-replace*
   regexp?
   relative-path?
   rename-file-or-directory
   replace-evt
   resolve-path
   reverse
   round
   seconds->date
   security-guard?
   semaphore?
   semaphore-peek-evt
   semaphore-peek-evt?
   semaphore-post
   semaphore-try-wait?
   semaphore-wait
   semaphore-wait/enable-break
   set-box!
   set-phantom-bytes!
   shared-bytes
   shell-execute
   simplify-path
   sin
   single-flonum?
   sleep
   split-path
   sqrt
   string
   string->bytes/latin-1
   string->bytes/locale
   string->bytes/utf-8
   string->immutable-string
   string->list
   string->number
   string->path
   string->path-element
   string->symbol
   string->uninterned-symbol
   string->unreadable-symbol
   string-append
   string-ci=?
   string-ci<=?
   string-ci<?
   string-ci>=?
   string-ci>?
   string-copy
   string-copy!
   string-downcase
   string-fill!
   string-foldcase
   string-length
   string-locale-downcase
   string-locale-ci<?
   string-locale-ci=?
   string-locale-ci>?
   string-locale-upcase
   string-locale<?
   string-locale=?
   string-locale>?
   string-normalize-nfc
   string-normalize-nfd
   string-normalize-nfkc
   string-normalize-nfkd
   string-port?
   string-ref
   string-set!
   string-titlecase
   string-upcase
   string-utf-8-length
   string<=?
   string<?
   string=?
   string>=?
   string>?
   string?
   struct->vector
   struct-type?
   struct?
   struct-accessor-procedure?
   struct-mutator-procedure?
   struct-constructor-procedure?
   struct-info
   struct-predicate-procedure?
   struct-type-info
   struct-type-make-constructor
   struct-type-make-predicate
   struct-type-property-accessor-procedure?
   struct-type-property?
   sub1
   subbytes
   subprocess?
   subprocess
   subprocess-group-enabled
   subprocess-kill
   subprocess-pid
   subprocess-status
   subprocess-wait
   substring
   symbol->string
   symbol-interned?
   symbol-unreadable?
   symbol<?
   symbol?
   sync
   sync/timeout
   sync/enable-break
   sync/timeout/enable-break
   system-big-endian?
   system-idle-evt
   system-language+country
   system-library-subpath
   system-path-convention-type
   system-type
   tan
   terminal-port?
   time-apply
   thread
   thread/suspend-to-kill
   thread?
   thread-cell?
   thread-cell-ref
   thread-cell-set!
   thread-cell-values?
   thread-dead?
   thread-dead-evt
   thread-dead-evt?
   thread-group?
   thread-receive
   thread-receive-evt
   thread-resume
   thread-resume-evt
   thread-rewind-receive
   thread-running?
   thread-send
   thread-receive
   thread-suspend
   thread-suspend-evt
   thread-try-receive
   thread-wait
   true-object?
   truncate
   unbox
   uncaught-exception-handler
   values
   vector
   vector->immutable-vector
   vector->list
   vector->pseudo-random-generator
   vector->pseudo-random-generator!
   vector->values
   vector-copy!
   vector-fill!
   vector-immutable
   vector-length
   vector-ref
   vector-set!
   vector-set-performance-stats!
   vector?
   version
   void
   void?
   weak-box?
   weak-box-value
   will-execute
   will-executor?
   will-register
   will-try-execute
   with-input-from-file
   with-output-to-file
   wrap-evt
   write
   write-byte
   write-bytes
   write-bytes-avail
   write-bytes-avail*
   write-bytes-avail/enable-break
   write-bytes-avail-evt
   write-char
   write-special
   write-special-avail*
   write-special-evt
   write-string
   zero?

   keyword<?
   string->keyword
   keyword->string
   keyword?

   cons pair?
   car cdr
   caar cadr cdar cddr
   caaar caadr cadar caddr cdaar cdadr cddar cdddr
   caaaar caaadr caadar caaddr cadaar cadadr caddar cadddr
   cdaaar cdaadr cdadar cdaddr cddaar cddadr cdddar cddddr

   mpair?
   mcons
   mcar
   mcdr
   set-mcar!
   set-mcdr!

   raise-argument-error
   raise-arguments-error
   raise-result-error
   raise-mismatch-error
   raise-range-error
   raise-arity-error
   raise-type-error

   struct:exn exn exn? exn-message exn-continuation-marks
   struct:exn:break exn:break exn:break? exn:break-continuation
   struct:exn:break:hang-up exn:break:hang-up exn:break:hang-up?
   struct:exn:break:terminate exn:break:terminate exn:break:terminate?
   struct:exn:fail exn:fail exn:fail?
   struct:exn:fail:contract exn:fail:contract exn:fail:contract?
   struct:exn:fail:contract:arity exn:fail:contract:arity exn:fail:contract:arity?
   struct:exn:fail:contract:divide-by-zero exn:fail:contract:divide-by-zero exn:fail:contract:divide-by-zero?
   struct:exn:fail:contract:non-fixnum-result exn:fail:contract:non-fixnum-result exn:fail:contract:non-fixnum-result?
   struct:exn:fail:contract:continuation exn:fail:contract:continuation exn:fail:contract:continuation?
   struct:exn:fail:contract:variable exn:fail:contract:variable exn:fail:contract:variable? exn:fail:contract:variable-id
   struct:exn:fail:read exn:fail:read exn:fail:read? exn:fail:read-srclocs
   struct:exn:fail:read:eof exn:fail:read:eof exn:fail:read:eof?
   struct:exn:fail:read:non-char exn:fail:read:non-char exn:fail:read:non-char?
   struct:exn:fail:filesystem exn:fail:filesystem exn:fail:filesystem?
   struct:exn:fail:filesystem:exists exn:fail:filesystem:exists exn:fail:filesystem:exists?
   struct:exn:fail:filesystem:version exn:fail:filesystem:version exn:fail:filesystem:version?
   struct:exn:fail:filesystem:errno exn:fail:filesystem:errno exn:fail:filesystem:errno? exn:fail:filesystem:errno-errno
   struct:exn:fail:network exn:fail:network exn:fail:network?
   struct:exn:fail:network:errno exn:fail:network:errno exn:fail:network:errno? exn:fail:network:errno-errno
   struct:exn:fail:out-of-memory exn:fail:out-of-memory exn:fail:out-of-memory?
   struct:exn:fail:unsupported exn:fail:unsupported exn:fail:unsupported?
   struct:exn:fail:user exn:fail:user exn:fail:user?

   prop:exn:srclocs exn:srclocs? exn:srclocs-accessor

   struct:srcloc srcloc srcloc?
   srcloc-source srcloc-line srcloc-column srcloc-position srcloc-span
   srcloc->string

   struct:date date? date make-date
   date-second date-minute date-hour date-day date-month date-year
   date-week-day date-year-day date-dst? date-time-zone-offset
   
   struct:date* date*? date* make-date*
   date*-nanosecond date*-time-zone-name

   struct:arity-at-least arity-at-least arity-at-least?
   arity-at-least-value

   [core:correlated? syntax?]
   [core:correlated-source syntax-source]
   [core:correlated-line syntax-line]
   [core:correlated-column syntax-column]
   [core:correlated-position syntax-position]
   [core:correlated-span syntax-span]
   [core:correlated-e syntax-e]
   [core:correlated->datum syntax->datum]
   [core:datum->correlated datum->syntax]
   [core:correlated-property syntax-property]
   [core:correlated-property-symbol-keys syntax-property-symbol-keys]))
