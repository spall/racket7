#lang racket/base

(require "internal-error.rkt"
         "engine.rkt")

(provide with-lock
         make-lock
         lock-acquire
         lock-release
         own-lock?)

(define-syntax-rule (with-lock (lock caller) expr ...)
  (begin
    (lock-acquire lock caller)
    (begin0
        (let () expr ...)
      (lock-release lock caller))))

(struct future-lock* (box owner))

(define (lock-owner lock)
  (future-lock*-owner lock))

(define (make-lock)
  (future-lock* 0 #f))

(define (lock-acquire lock caller [block? #t])
  (let loop ()
    (cond
      [(and (= 0 (future-lock*-box lock)) (chez:unsafe-struct-cas! lock 0 0 1)) ;; got lock
       (unless (chez:unsafe-struct-cas! lock 1 #f caller)
         (internal-error "Lock already has owner."))
       #t]
      [block?
       (loop)]
      [else
       #f])))

(define (lock-release lock caller)
  (when (eq? caller (future-lock*-owner lock))
    (unless (chez:unsafe-struct-cas! lock 1 caller #f)
      (internal-error "Failed to reset owner\n"))
    (unless (chez:unsafe-struct-cas! lock 0 1 0)
      (internal-error "Lock release failed\n"))))

(define (own-lock? lock caller)
  (and (eq? caller (future-lock*-owner lock))
       (begin0
           #t
         (unless (= 1 (future-lock*-box lock))
           (internal-error "Caller 'owns' lock but lock is free.")))))

