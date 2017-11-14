#lang racket/base

;; lock free work stealing double ended queue.

(provide push-bottom
         pop-bottom
         steal
         make-cwsdeque)

(struct cwsdeque (top bottom array) #:mutable)

;; fix name
(struct circular-array (log-size segment) #:mutable)
                                  
(define (make-circular-array log-size)
  (circular-array log-size (make-vector (arithmetic-shift 1 log-size)
                                        0)))

(define (grow-array a b t)
  (define na (make-circular-array (+ (circular-array-log-size a) 1)))
  (for ([i (in-range t b)])
    (array-put na i (array-get a i)))
  na)

(define (array-size a)
  (arithmetic-shift 1 (circular-array-log-size a)))

(define (array-get a pos)
   (vector-ref (circular-array-segment a)
              (modulo pos (array-size a))))

(define (array-put a pos val)
  (vector-set! (circular-array-segment a)
               (modulo pos (array-size a))
               val))

;; q old new
(define cas-top! box-cas!)

(define INIT-LOG-SIZE 10)

(define (make-cwsdeque)
  (cwsdeque (box 0) 0 (make-circular-array INIT-LOG-SIZE)))

;; invoked only by q owner
(define (push-bottom q w)
  (define b (cwsdeque-bottom q))
  (define t (unbox (cwsdeque-top q)))
  (define a (cwsdeque-array q))

  (define size (- b t))
  (when (>= size (- (array-size a) 1))
    (set! a (grow-array a b t))
    (set-cwsdeque-array! q a))

  (array-put a b w)
  (set-cwsdeque-bottom! q (+ b 1)))

;; invoked only by q owner
(define (pop-bottom q)
  (define b (cwsdeque-bottom q))
  (define a (cwsdeque-array q))
  (set! b (- b 1))
  (set-cwsdeque-bottom! q b)
  (define t (unbox (cwsdeque-top q)))
  (define size (- b t))
  (cond
    [(< size 0)
     (set-cwsdeque-bottom! q t)
     'Empty]
    [else
     (define o (array-get a b))
     (unless (> size 0)
       (unless (cas-top! (cwsdeque-top q) t (+ t 1))
         (set! o 'Empty))
       (set-cwsdeque-bottom! q (+ t 1)))
     o]))
     
(define (steal q)
  (define t (unbox (cwsdeque-top q)))
  (define b (cwsdeque-bottom q))
  (define a (cwsdeque-array q))

  (define size (- b t))
  (cond
    [(<= size 0)
     'Empty]
    [else
     (define o (array-get a t))
     (if (cas-top! (cwsdeque-top q) t (+ t 1))
         o
         'Abort)]))
      

