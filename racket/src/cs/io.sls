(library (io)
  (export)
  (import (chezpart)
          (rename (only (chezscheme)
                        read-char peek-char
                        standard-input-port standard-output-port standard-error-port
                        close-input-port close-output-port
                        current-directory
                        format
                        error
                        input-port? output-port?
                        file-position flush-output-port
                        file-symbolic-link?)
                  [standard-input-port current-input-port]
                  [standard-output-port current-output-port]
                  [standard-error-port current-error-port]
                  [input-port? chez:input-port?]
                  [output-port? chez:output-port?]
                  [flush-output-port flush-output])
          (core)
          (thread))
  ;; Tie knots:
  (define (path? v) (is-path? v))
  (define (path->string v) (1/path->string v))
  (define path->complete-path
    (case-lambda
     [(v) (1/path->complete-path v)]
     [(v wrt) (1/path->complete-path v wrt)]))
  (define (absolute-path? v) (1/absolute-path? v))
  (define (relative-path? v) (1/relative-path? v))

  (define string-locale-downcase string-downcase)

  (define (char-blank? v) (char-whitespace? v))
  (define (char-graphic? v) #t)
  
  (define (read-byte in) (get-u8 in))
  (define (read-bytes-avail!* bstr in start-pos end-pos)
    (if (input-port-ready? in)
        (get-bytevector-some! in bstr start-pos (- end-pos start-pos))
        0))
  (define (write-bytes-avail* bstr out start-pos end-pos)
    (define len (- end-pos start-pos))
    (put-bytevector out bstr start-pos len)
    (flush-output-port out)
    len)
  (define (write-bytes bstr out)
    (put-bytevector out bstr 0 (bytevector-length bstr)))

  (define-syntax with-exn:fail:filesystem
    (syntax-rules ()
      [(_ expr)
       (guard
        (x [else (convert-exception-to-exn:fail:filesystem x)])
        expr)]))

  (define (convert-exception-to-exn:fail:filesystem v)
    (raise
     (|#%app|
      (if (i/o-file-already-exists-error? v)
          exn:fail:filesystem:exists
          exn:fail:filesystem)
      (string-append
       (if (who-condition? v)
           (chez:format "~a: " (condition-who v))
           "")
       (cond
        [(format-condition? v)
         (apply chez:format
                (condition-message v)
                (condition-irritants v))]
        [(message-condition? v)
         (condition-message v)]
        [else
         (chez:format "~s" v)]))
      (current-continuation-marks))))

  (define file-stream-buffer-mode
    (case-lambda
     [(p)
      (if (chez:input-port? p)
          (if (zero? (binary-port-input-size p))
              'none
              'block)
          (if (zero? (binary-port-output-size p))
              'none
              'block))]
     [(p mode)
      (if (chez:input-port? p)
          (set-binary-port-input-buffer! p (if (eq? mode 'block)
                                               (make-bytevector 4096)
                                               (make-bytevector 0)))
          (set-binary-port-output-buffer! p (if (eq? mode 'block)
                                                (make-bytevector 4096)
                                                (make-bytevector 0))))]))
  (define peek-byte lookahead-u8)

  ;; Host's notion of path is just a string:
  (define (bytes->path bstr)
    (1/bytes->string/utf-8 bstr))
  (define (path->bytes p)
    (1/string->bytes/utf-8 p))

  (define (system-path-convention-type) 'unix)

  (define (directory-exists? p)
    (file-directory? p))
  
  (define (file-exists? p)
    (and (chez:file-exists? p)
         (not (file-directory? p))))
  
  (define (link-exists? p)
    (file-symbolic-link? p))
  
  (define (directory-list p)
    (chez:directory-list p))

  (define (make-directory p)
    (with-exn:fail:filesystem
     (mkdir p)))

  (define (delete-file p)
    (with-exn:fail:filesystem
     (chez:delete-file p)))
  
  (define (delete-directory p)
    (with-exn:fail:filesystem
     (chez:delete-directory p)))
  
  (define file-or-directory-modify-seconds
    (case-lambda
     [(p)
      (time-second (with-exn:fail:filesystem
                    (file-modification-time p)))]
     [(p secs)
      (if secs
          (error 'file-or-directory-modify-seconds "cannot set modify seconds")
          (with-exn:fail:filesystem
           (file-or-directory-modify-seconds p)))]
     [(p secs fail)
      (if secs
          (file-or-directory-modify-seconds p secs)
          (guard
           (exn [else (fail)])
           (time-second (file-modification-time p))))]))

  (define (file-or-directory-permissions path mode)
    (cond
     [(eq? 'bits mode) (get-mode path #f)]
     [(not mode)
      (let ([bits (get-mode path #f)])
        (append
         (if (zero? (bitwise-and #o100  bits)) '() '(read))
         (if (zero? (bitwise-and #o200  bits)) '() '(write))
         (if (zero? (bitwise-and #o400  bits)) '() '(execute))))]
     [else
      (chmod path mod)]))

  (define (rename-file-or-directory old-pathname new-pathname exists-ok?)
    (with-exn:fail:filesystem
     (rename-file old-pathname new-pathname)))

  (define file-identities (make-hashtable equal-hash-code equal?))
  (define (file-or-directory-identity p as-link?)
    (let ([key (1/path->string (1/simplify-path (1/path->complete-path p)))])
      (let ([n (hashtable-ref file-identities key #f)])
        (or n
            (let ([n (hashtable-size file-identities)])
              (hashtable-set! file-identities key n)
              n)))))

  (define (file-size p)
    (1/error 'file-size "not yet supported"))

  (define (copy-file src dest exists-ok?)
    (1/error 'copy-file "not yet supported"))

  (define (make-file-or-directory-link to path)
    (1/error 'make-file-or-directory-link "not yet supported"))

  (define (filesystem-root-list)
    (1/error 'filesystem-root-list "not yet supported"))
  
  (define (resolve-path p) p)
  
  (define open-input-file
    (case-lambda
     [(path mode mode2)
      (open-input-file path)]
     [(path mode)
      (open-input-file path)]
     [(path)
      (with-exn:fail:filesystem
       (open-file-input-port path))]))

  (define open-output-file
    (case-lambda
     [(path) (open-output-file path #f #f)]
     [(path mode) (open-output-file path mode #f)]
     [(path mode mode2)
      (let ([mode? (lambda (s) (or (eq? mode s) (eq? mode2 s)))])
        (with-exn:fail:filesystem
         (open-file-output-port path (cond
                                      [(mode? 'truncate) (file-options no-fail)]
                                      [(mode? 'must-truncate) (file-options no-create)]
                                      [(mode? 'update) (file-options no-create no-truncate)]
                                      [(mode? 'can-update) (file-options no-fail no-truncate)]
                                      [(mode? 'replace) (file-options no-fail)]
                                      [(mode? 'truncate/replace) (file-options no-fail)]
                                      [(mode? 'append) (chez:error 'open-output-file "'append mode not supported")]
                                      [else (file-options)]))))]))

  (define file-truncate truncate-file)

  (define (primitive-table key)
    (case key
      [(|#%evt|) |#%evt-instance|]
      [else #f]))

  (define (terminal-port? p) #f)

  (include "compiled/io.scm")
  
  ;; Initialize:
  (|#%app| 1/current-directory (current-directory)))
