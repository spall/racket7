#lang racket/base

(require racket/future)

(provide atomically
         current-atomic
         start-atomic
         end-atomic
         end-atomic-callback
         set-end-atomic-callback!)

(define-syntax-rule (atomically expr ...)
  (begin
    (start-atomic)
    (begin0
     (let () expr ...)
     (end-atomic))))

