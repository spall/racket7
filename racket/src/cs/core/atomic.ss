
;; atomic works because it is confined to a single thread. fake atomicity is acceptable.
(define current-atomic (internal-make-thread-parameter #f))

; todo (define-syntax-rule (

(define (start-atomic)
  (current-atomic #t))

(define (end-atomic)
  (current-atomic #f))

