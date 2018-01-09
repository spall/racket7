#lang racket/base

(require "check.rkt"
         "internal-error.rkt"
         "engine.rkt"
         "atomic.rkt"
         "parameter.rkt"
         "../common/queue.rkt"
         "../common/deque.rkt"
         "thread.rkt"
         "lock.rkt"
         racket/unsafe/ops)

(provide futures-enabled?
         processor-count
         current-future
         future
         future?
         would-be-future
         touch
         future-block
         future-wait
         current-future-prompt
         future:condition-broadcast
         future:condition-signal
         future:condition-wait
         future:make-condition
	 halt-workers
         resume-workers
         signal-future
         reset-future-logs-for-tracing!
         mark-future-trace-end!)

;; not sure of order here...
(define (get-caller)
  (cond
    [(current-future)
     (current-future)]
    [(not (= 0 (get-pthread-id)))
     (get-pthread-id)]
    [else
     (current-thread)]))


;; ---------------------------- futures ----------------------------------


(define ID (box 1))

(define get-next-id
  (lambda ()
    (let ([id (unbox ID)])
      (if (box-cas! ID id (+ 1 id))
          id
          (get-next-id)))))

(define (processor-count)
  1)

(define futures-enabled? threaded?)

(struct future* (id cond lock prompt
                    [flags #:mutable] [engine-or-thunk #:mutable] 
                    [cont #:mutable] [result #:mutable]))
;; authentic.?

(define (set-future*-cond-wait?! f b)
  (set-future*-flags!
   f
   (if b
       (unsafe-fxior (future*-flags f) 1)
       (unsafe-fxand (future*-flags f) 30)))) ;; 11110 = 16 + 8 + 4 + 2 = 30

(define (future*-cond-wait? f)
  (unsafe-fx= (unsafe-fxand (future*-flags f) 1) 1))

(define (set-future*-resumed?! f b)
  (set-future*-flags!
   f
   (if b
       (unsafe-fxior (future*-flags f) 2)     ;; 00010
       (unsafe-fxand (future*-flags f) 29)))) ;; 11101 = 16 + 8 + 4 + 1 = 29

(define (future*-resumed? f)
  (unsafe-fx= (unsafe-fxand (future*-flags f) 2) 2))

(define (set-future*-blocked?! f b)
  (set-future*-flags!
   f
   (if b
       (unsafe-fxior (future*-flags f) 4)      ;; 00100
       (unsafe-fxand (future*-flags f) 28))))  ;; 11011 = 16 + 8 + 2 + 2 = 28

(define (future*-blocked? f)
  (unsafe-fx= (unsafe-fxand (future*-flags f) 4) 4)) ;; 00100

(define (set-future*-done?! f b)
  (set-future*-flags!
   f
   (if b
       (unsafe-fxior (future*-flags f) 8)         ;; 01000
       (unsafe-fxand (future*-flags f) 23))))     ;; 10111 = 16 + 4 + 2 + 1 = 23

(define (future*-done? f)
  (unsafe-fx= (unsafe-fxand (future*-flags f) 8) 8))

(define (set-future*-would-be?! f b)
  (set-future*-flags!
   f
   (if b
       (unsafe-fxior (future*-flags f) 16)
       (unsafe-fxand (future*-flags f) 15))))    ;; 01111 = 8 + 4 + 2 + 1 = 15

(define (future*-would-be? f)
  (unsafe-fx= (unsafe-fxand (future*-flags f) 16) 16))

(define (create-future would-be-future?)
  (future* (get-next-id) ;; id
           (future:make-condition) ;; cond
           (make-lock) ;; lock
           (make-continuation-prompt-tag 'future) ;; prompt
           (if would-be-future? #;flags ;; would-be? done? blocked? resumed? cond-wait?
               16 ;; 10000
               0) ;; 00000 
           #f   ;; engine-or-thunk
           #f   ;; cont
           #f   ;; result
           ))

(define future? future*?)

(define current-future (internal-make-thread-parameter #f))

(define (current-future-prompt)
  (if (current-future)
      (future*-prompt (current-future))
      (internal-error "Not running in a future.")))

(define (thunk-wrapper f thunk)
  (lambda ()
    (call-with-continuation-prompt
     (lambda ()
       (let ([result (thunk)])
         (with-lock ((future*-lock f) (current-future))
           (set-future*-result! f result)
           (set-future*-done?! f #t)
           (future:condition-broadcast (future*-cond f)))))
     (future*-prompt f))))

(define/who (future thunk)
  ;(check who (procedure-arity-includes/c 0) thunk)
  (cond
    [(not (futures-enabled?))
     (would-be-future thunk)]
    [else
     (let ([f (create-future #f)])
       (set-future*-engine-or-thunk! f ;(thunk-wrapper f thunk)
                                     (make-engine (thunk-wrapper f thunk) #f #t))
       (schedule-future f)
       f)]))

(define/who (would-be-future thunk)
  (check who (procedure-arity-includes/c 0) thunk)
  (let ([f (create-future #t)])
    (set-future*-engine-or-thunk! f (thunk-wrapper f thunk))
    f))

;;(define
;; delay, force, promise?
;;;;;;;;;;;;;;;;;;;;;;;

(define/who (touch f)
  ;(check who future*? f)
  (cond
    [(future*-done? f)
     (future*-result f)]
    [(future*-would-be? f)
     ((future*-engine-or-thunk f))
     (future*-result f)]
    [(lock-acquire (future*-lock f) (get-caller) #f) ;; got lock
     (when (or (and (not (future*-blocked? f)) (not (future*-done? f)))
               (and (future*-blocked? f) (not (future*-cont f))))
       (future:condition-wait (future*-cond f) (future*-lock f)))
     (future-awoken f)]
    [else
     (touch f)]))

(define (future-awoken f)
  (cond
    [(future*-done? f) ;; someone else ran continuation
     (lock-release (future*-lock f) (get-caller))
     (future*-result f)]
    [(future*-blocked? f) ;; we need to run continuation
     (set-future*-blocked?! f #f)
     (set-future*-resumed?! f #t)
     (lock-release (future*-lock f) (get-caller))
     ((future*-cont f) '())
     (future*-result f)]
    [else
     (internal-error "Awoken but future is neither blocked nor done.")]))

;; called from chez layer.
(define (future-block)
  (define f (current-future))
  (when (and f (not (future*-blocked? f)) (not (future*-resumed? f)))
    ;(with-lock ((future*-lock f) f)
    (set-future*-blocked?! f #t)
    ;(printf "Engine block 1; current future is ~a\n" f)
    (engine-block)))

;; called from chez layer.
;; this should never be called from outside a future.
(define (future-wait)
  (define f (current-future))
  (with-lock ((future*-lock f) f)
    (future:condition-wait (future*-cond f) (future*-lock f))))

;; futures and conditions

;; todo: in struct.ss add unsafe-struct*-cas! just call vector-cas!
;; see exmaples in file.
;; remove box from deque and just cas on field.

;; not running futures for long enough?
;; capturing continuation too often?
;; what other reason might futures be slow?
;; what is C implementation doing so that its fibonacci is so much faster?

(define (wait-future f m)
  (set-future*-cond-wait?! f #t)
  (lock-release m (get-caller))
  ;(printf "engine block 2\n")
  (engine-block))

(define (awaken-future f)
  (set-future*-cond-wait?! f #f)
  (schedule-future f))

;; --------------------------- conditions ------------------------------------

(struct future-condition* (queue lock))

(define (future:make-condition)
  (future-condition* (make-queue) (make-lock)))

(define (future:condition-wait c m)
  (define caller (get-caller))
  (if (own-lock? m caller)
      (begin
        (with-lock ((future-condition*-lock c) caller)
          (queue-add! (future-condition*-queue c) caller))
        (if (future? caller)
            (wait-future caller m)
            (thread-condition-wait (lambda () (lock-release m caller))))
        (lock-acquire m (get-caller))) ;; reaquire lock
      (internal-error "Caller does not hold lock\n")))

(define (signal-future f)
  (future:condition-signal (future*-cond f)))

(define (future:condition-signal c)
  (with-lock ((future-condition*-lock c) (get-caller))
    (let ([waitees (future-condition*-queue c)])
      (unless (queue-empty? waitees)
        (let ([waitee (queue-remove! waitees)])
          (if (future? waitee)
              (awaken-future waitee)
              (thread-condition-awaken waitee)))))))

(define (future:condition-broadcast c)
  (with-lock ((future-condition*-lock c) (get-caller))
    (define waitees '())
    (queue-remove-all! (future-condition*-queue c)
                       (lambda (e)
                         (set! waitees (cons e waitees))))
    (let loop ([q waitees])
      (unless (null? q)
        (let ([waitee (car q)])
          (if (future? waitee)
              (awaken-future waitee)
              (thread-condition-awaken waitee))
          (loop (cdr q)))))))

;; ------------------------------------- future scheduler ----------------------------------------

(define THREAD-COUNT 2)
(define TICKS 1000000000000)

(define main-queue (make-cwsdeque))
(define future-workers #f)
(define workers-counts #f)

(struct worker (id lock mutex cond [count #:mutable]
                   [queue #:mutable] [pthread #:mutable]
                   [flags #:mutable]))

(define (set-worker-idle?! w b)
  (set-worker-flags!
   w
   (if b
       (unsafe-fxior (worker-flags w) 1)
       (unsafe-fxand (worker-flags w) 6))))  ;; 110 = 4 + 2 

(define (worker-idle? w)
  (unsafe-fx= (unsafe-fxand (worker-flags w) 1) 1))

(define (set-worker-die?! w b)
  (set-worker-flags!
   w
   (if b
       (unsafe-fxior (worker-flags w) 2)
       (unsafe-fxand (worker-flags w) 5)))) ;; 101 = 4 + 1

(define (worker-die? w)
  (unsafe-fx= (unsafe-fxand (worker-flags w) 2) 2))

(define (set-worker-halt?! w b)
  (set-worker-flags!
   w
   (if b
       (unsafe-fxior (worker-flags w) 4)
       (unsafe-fxand (worker-flags 2) 3)))) ;; 011 = 3

(define (worker-halt? w)
  (unsafe-fx= (unsafe-fxand (worker-flags w) 4) 4))

;; I think this atomically is sufficient to guarantee scheduler is only created once.
(define (maybe-start-workers)
  (atomically
   (unless future-workers
     (let ([workers (create-workers)])
       (set! future-workers workers)
       (start-workers workers)))))

;; why do we even need to acquire lock when setting die?! to true?
(define (kill-scheduler)
  (when future-workers
    (let loop ([in 1])
      (when (< in (+ 1 THREAD-COUNT))
        (let ([w (vector-ref future-workers in)])
          (set-worker-die?! w #t))
        (loop (+ 1 in))))))

(define halt-cond (chez:make-condition))
(define halt-mutex (chez:make-mutex))
(define halt-count (box 0))
(define (halt-count+1)
  (define hc (unbox halt-count))
  (unless (box-cas! halt-count hc (+ 1 hc))
    (halt-count+1)))

;; ditto
;; only called by main thread for gc?
(define (halt-workers)
  (when future-workers
    (let g ()
      (when (< (chez:active-threads) (+ 1 (unbox halt-count)))
        (g)))
    (set-box! halt-count 0)
    (for ([w (in-vector future-workers 1)])
      (set-worker-halt?! w #t))
    (let f ()
      (when (> (chez:active-threads) 1) ;; block until all workers have halted
        (f)))))

;; only called by main thread for gc?
(define (resume-workers)
  (when future-workers
    (for ([w (in-vector future-workers 1)])
      (set-worker-halt?! w #f))
    (chez:condition-broadcast halt-cond)))

(define (create-workers)
  (define worker-vec (make-vector (+ 1 THREAD-COUNT) #f))
  (set! workers-counts (make-vector (+ 1 THREAD-COUNT) 0))
  (let loop ([id 1])
    (when (< id (+ 1 THREAD-COUNT))
      (vector-set! worker-vec id (worker id (make-lock) (chez:make-mutex) (chez:make-condition) 0 (make-cwsdeque) #f 1))
      (loop (+ 1 id))))
  worker-vec)

;; When a new thread is forked it inherits the values of thread parameters from its creator
;; So, if current-atomic is set for the main thread and then new threads are forked, those new
;; threads current-atomic will be set and then never unset because they will not run code that
;; unsets it.
(define (start-workers workers)
  (let loop ([in 1])
    (when (< in (+ 1 THREAD-COUNT))
      (let ([w (vector-ref workers in)])
        (set-worker-pthread! w (fork-pthread (lambda ()
                                               (current-atomic 0)
                                               (current-thread #f)
                                               (current-engine-state #f)
                                               (current-future #f)
                                               ((worker-scheduler-func w))))))
      (loop (+ 1 in)))))

(define work1? #f)
(define work2? #f)

(define (schedule-future f)
  (define id (get-pthread-id))
  (cond
    [(= 0 id)
     (maybe-start-workers)
     (push-bottom main-queue f)
     ;(printf "put future on queue\n")
     (define w (pick-worker))
     (when w
       ;(printf "waking up worker ~a\n" (worker-id w))
       (chez:mutex-acquire (worker-mutex w))
       (chez:condition-signal (worker-cond w))
       (chez:mutex-release (worker-mutex w)))]
    [else
    #;(cond
      [(and (= id 1) (not work1?))
       ;(printf "Worker ~a adding to queue\n" id)
       (set! work1? #t)]
      [(and (= id 2) (not work2?))
       ;(printf "Worker ~a adding to queue\n" id)
       (set! work2? #t)])
       
     (push-bottom (worker-queue (vector-ref future-workers id)) f)]))

;; pick idle worker.
(define (pick-worker)
  (let loop ([in 1])
    (if (< in (+ 1 THREAD-COUNT))
        (let ([w (vector-ref future-workers in)])
          (cond
            [(worker-idle? w)
             w]
            [else
             (loop (+ 1 in))]))
        (vector-ref future-workers 1))))

;; workers are the only ones who give themselves work now. so, only need to check if main thread
;; or peer has potential work
(define (wait-for-work w)
  ;(printf "In wait for work;\n")
  (let try ()
    (chez:mutex-acquire (worker-mutex w))
    (define work (steal main-queue))
    (cond
      [(equal? work 'Empty) ;; no work. go to sleep
       (set-worker-idle?! w #t)
       ;(printf "Worker ~a going to sleep; did ~a work\n" (worker-id w) (vector-ref workers-counts (worker-id w)))
       (chez:condition-wait (worker-cond w) (worker-mutex w))
       (set-worker-idle?! w #f)
       ;(printf "worker awoken\n")
       (chez:mutex-release (worker-mutex w))
       (try)] ;; awoken so must be work on main thread.
      [(equal? work 'Abort) ;; lost race so try again
      (chez:mutex-release (worker-mutex w))
       (try)]
      [else
      (chez:mutex-release (worker-mutex w))
       work])))

(define (worker-scheduler-func worker)
  (lambda ()
    
    (define (loop)
      ;(printf "worker looping\n")
      (cond
        [(worker-die? worker) ;; worker was killed
	;(printf "worker dying\n")
         (void)]
	[(worker-halt? worker) ;; worker is halting for gc
	 (chez:mutex-acquire halt-mutex)
         (halt-count+1)
	 (chez:condition-wait halt-cond halt-mutex)
	 (chez:mutex-release halt-mutex)
	 (loop)]
        [else
         (define work (pop-bottom (worker-queue worker)))
         (cond
           [(equal? work 'Empty)
            ;; try to steal
	    ;(printf "worker going to steal\n")
            (set! work (steal-work worker 0))  
	    
            (do-work (if (eq? work 'FAIL)
                         (wait-for-work worker)
                         work))]
           [else
            ;(printf "Worker ~a running work from own queue\n" (worker-id worker))
            (do-work work)])
         (set-worker-idle?! worker #f)
	 
         (loop)]))
    
    (define (complete ticks args)
      (void))
    
    (define (expire future worker)
      (lambda (new-eng)
        (set-future*-engine-or-thunk! future new-eng)
        (cond
          [(positive? (current-atomic))
           ;(printf "Future ~a expired\n" (future*-id future))
           ((future*-engine-or-thunk future) TICKS (prefix future) complete (expire future worker))]
          [(future*-resumed? future) ;; run to completion
           ;(printf "Future ~a expired\n" (future*-id future))
           ((future*-engine-or-thunk future) TICKS void complete (expire future worker))]
          [(future*-cond-wait? future)
           ;(printf "Future ~a expired for cond-wait\n" (future*-id future))
           (void)]
          [(not (future*-cont future)) ;; don't want to reschedule future with a saved continuation
           ;(printf "Future ~a expired\n" (future*-id future))
           ((future*-engine-or-thunk future) TICKS (prefix future) complete (expire future worker))]
          [else
           (with-lock ((future*-lock future) (get-caller))
             ;(printf "Future ~a expired captured continuation\n" (future*-id future))
             (future:condition-signal (future*-cond future)))])))
    
    (define (prefix f)
      (lambda ()
        (when (future*-blocked? f)
            (call-with-composable-continuation
             (lambda (k)
               (with-lock ((future*-lock f) (current-future))
                 (set-future*-cont! f k))
		 ;(printf "engine block 3\n")
               (engine-block))
             (future*-prompt f)))))

    (define (do-work work)
      (unless (future*-cond-wait? work)
        ;(printf "Worker ~a running future ~a\n" (worker-id worker) (future*-id work))
        ;(set-worker-count! worker (+ 1 (worker-count worker)))
	(vector-set! workers-counts (worker-id worker) (+ 1 (vector-ref workers-counts (worker-id worker))))
        (current-future work)
        ((future*-engine-or-thunk work) TICKS (prefix work) complete (expire work worker)) ;; call engine.
        (current-future #f)))
    
    (loop)))


;; Code for work stealing
(define (pick-rand-worker excluded)
  (define rand (+ 1 (random THREAD-COUNT)))
  (define rand-worker (vector-ref future-workers rand))
  (if (eq? excluded rand-worker)
      (pick-rand-worker excluded)
      rand-worker))

(define (steal-from-main)
  (define w (steal main-queue))
  (cond
   [(eq? w 'Abort)
    (steal-from-main)]
   [else
    w]))

(define (steal-from-peer excluded)
  (define peer (pick-rand-worker excluded))
  (let loop ()
    (define w (steal (worker-queue peer)))
    (cond
     [(eq? w 'Abort)
      (loop)]
     [else
      w])))

(define RETRY-MAX 500)

;; worker is attempting to steal work from peers or main thread
(define (steal-work worker retry)
  (define mtwork (steal-from-main))
  (cond
   [(>= retry RETRY-MAX)
    'FAIL]	
   [(and (eq? mtwork 'Empty) (< THREAD-COUNT 2))
    'FAIL]
   [(eq? mtwork 'Empty)
    (let ([pwork (steal-from-peer worker)])
      (cond
       [(eq? pwork 'Empty)
        (steal-work worker (+ 1 retry))]
       [else
        pwork]))]
   [else
    mtwork]))
;; ----------------------------------------

(define (reset-future-logs-for-tracing!)
  (void))

(define (mark-future-trace-end!)
  (void))
