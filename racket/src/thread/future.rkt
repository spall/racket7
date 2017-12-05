#lang racket/base

(require "check.rkt"
         "internal-error.rkt"
         "engine.rkt"
         "atomic.rkt"
         "parameter.rkt"
         "../common/queue.rkt"
         "../common/deque.rkt"
         "thread.rkt"
         "lock.rkt")

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
                    would-be? [thunk #:mutable] [engine #:mutable] 
                    [cont #:mutable] [result #:mutable] [done? #:mutable]  
                    [blocked? #:mutable][resumed? #:mutable] 
                    [cond-wait? #:mutable]))

(define (create-future would-be-future?)
  (future* (get-next-id) ;; id
           (future:make-condition) ;; cond
           (make-lock) ;; lock
           (make-continuation-prompt-tag 'future) ;; prompt
           would-be-future? ;; would-be?
           #f   ;; thunk
           #f   ;; engine
           #f   ;; cont
           #f   ;; result
           #f   ;; done?
           #f   ;; blocked?
           #f   ;; resumed?
           #f)) ;; cond-wait?

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
       (set-future*-engine! f (make-engine (thunk-wrapper f thunk) #f #t))
       (schedule-future f)
       f)]))

(define/who (would-be-future thunk)
  (check who (procedure-arity-includes/c 0) thunk)
  (let ([f (create-future #t)])
    (set-future*-thunk! f (thunk-wrapper f thunk))
    f))

(define/who (touch f)
  ;(check who future*? f)
  (cond
    [(future*-done? f)
     (future*-result f)]
    [(future*-would-be? f)
     ((future*-thunk f))
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

(define global-scheduler #f)
(define (scheduler-running?)
  (not (not global-scheduler)))

(struct worker (id lock mutex cond [count #:mutable]
                   [queue #:mutable] [idle? #:mutable] 
                   [pthread #:mutable #:auto] [die? #:mutable #:auto]
                   [halt? #:mutable #:auto])
  #:auto-value #f)

(struct scheduler (queue workers) #:mutable) ;; queue is owned by main thread.

;; I think this atomically is sufficient to guarantee scheduler is only created once.
(define (maybe-start-scheduler)
  (atomically
   (unless global-scheduler
     (set! global-scheduler (scheduler (make-cwsdeque) #f))
     (let ([workers (create-workers)])
       (set-scheduler-workers! global-scheduler workers)
       (start-workers workers)))))

;; why do we even need to acquire lock when setting die?! to true?
(define (kill-scheduler)
  (when global-scheduler 
    (for-each (lambda (w)
                ;(with-lock ((worker-lock w) (get-caller))
                (set-worker-die?! w #t))
              (scheduler-workers global-scheduler))))

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
  (when global-scheduler
    (let g ()
      (when (< (chez:active-threads) (+ 1 (unbox halt-count)))
        (g)))
    (set-box! halt-count 0)
    (for-each (lambda (w)
    	        ;(with-lock ((worker-lock w) (get-caller))
                (set-worker-halt?! w #t))
	      (scheduler-workers global-scheduler))
    (let f ()
      (when (> (chez:active-threads) 1) ;; block until all workers have halted
        (f)))))

;; only called by main thread for gc?
(define (resume-workers)
  (when global-scheduler
    (for-each (lambda (w)
                ;(with-lock ((worker-lock w) (get-caller))
                  ;(chez:mutex-acquire (worker-mutex w))
                  (set-worker-halt?! w #f))
                  ;(chez:mutex-release (worker-mutex w))))
              (scheduler-workers global-scheduler))
    (chez:condition-broadcast halt-cond)))

(define (create-workers)
  (let loop ([id 1])
    (cond
      [(< id (+ 1 THREAD-COUNT))
       (cons (worker id (make-lock) (chez:make-mutex) (chez:make-condition) 0 (make-cwsdeque) #t)
             (loop (+ id 1)))]
      [else
       '()])))

;; When a new thread is forked it inherits the values of thread parameters from its creator
;; So, if current-atomic is set for the main thread and then new threads are forked, those new
;; threads current-atomic will be set and then never unset because they will not run code that
;; unsets it.
(define (start-workers workers)
  (for-each (lambda (w)
              (set-worker-pthread! w (fork-pthread (lambda ()
                                                     (current-atomic 0)
                                                     (current-thread #f)
                                                     (current-engine-state #f)
                                                     (current-future #f)
                                                     ((worker-scheduler-func w))))))
            workers))

(define (schedule-future f)
  (define id (get-pthread-id))
  (cond
    [(= 0 id) ;; main thread
     (maybe-start-scheduler)
     (push-bottom (scheduler-queue global-scheduler) f)
     ;; need to wake up at least 1 worker, so they will run this future.
     ;; easy to just wake up all of them.
     (define w (pick-worker))
     ;(for-each (lambda (w)
     (when w
       (chez:mutex-acquire (worker-mutex w))
       (chez:condition-signal (worker-cond w))
       (chez:mutex-release (worker-mutex w)))]
    [else ;; worker. so add to it's own queue
     (define w (car (list-tail (scheduler-workers global-scheduler) (- id 1))))
     (push-bottom (worker-queue w) f)]))

;; pick idle worker.
(define (pick-worker)
  (define workers (scheduler-workers global-scheduler))
  (let loop ([w (car workers)]
             [ws (cdr workers)])
    (cond
      [(worker-idle? w) 
       w]
      [(null? ws) ;; no workers are idle
       #f]
      [else
       (loop (car ws) (cdr ws))])))

;; workers are the only ones who give themselves work now. so, only need to check if main thread
;; has potential work
(define (wait-for-work w)
  ;(printf "In wait for work; worker ~a ran ~a futures since beginning of time\n" (worker-id w) (worker-count w))
  (let try ()
    (define work (steal (scheduler-queue global-scheduler)))
    (cond
      [(equal? work 'Empty) ;; no work. go to sleep
       (chez:mutex-acquire (worker-mutex w))
       (set-worker-idle?! w #t)
       (printf "Worker ~a going to sleep, received Abort ~a times\n" (worker-id w) (worker-count w))
       (chez:condition-wait (worker-cond w) (worker-mutex w))
       (set-worker-idle?! w #f)
       (chez:mutex-release (worker-mutex w))
       (try)] ;; awoken so must be work on main thread.
      [(equal? work 'Abort) ;; lost race so try again
       (try)] ;; should i add a timeout?
      [else
       work])))

(define (worker-scheduler-func worker)
  (lambda ()
    
    (define (loop)
      (cond
        [(worker-die? worker) ;; worker was killed
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
            (set! work (steal-work worker))
            (do-work (if work
                         work
                         (wait-for-work worker)))]
           [else
            ;(printf "Worker ~a running work from own queue\n" (worker-id worker))
            (do-work work)])
         (set-worker-idle?! worker #f)
         (loop)]))
    
    (define (complete ticks args)
      (void))
    
    (define (expire future worker)
      (lambda (new-eng)
        (set-future*-engine! future new-eng)
        (cond
          [(positive? (current-atomic))
           ;(printf "Future ~a expired\n" (future*-id future))
           ((future*-engine future) TICKS (prefix future) complete (expire future worker))]
          [(future*-resumed? future) ;; run to completion
           ;(printf "Future ~a expired\n" (future*-id future))
           ((future*-engine future) TICKS void complete (expire future worker))]
          [(future*-cond-wait? future)
           ;(printf "Future ~a expired for cond-wait\n" (future*-id future))
           (void)]
          [(not (future*-cont future)) ;; don't want to reschedule future with a saved continuation
           ;(printf "Future ~a expired\n" (future*-id future))
           ((future*-engine future) TICKS (prefix future) complete (expire future worker))]
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
               (engine-block))
             (future*-prompt f)))))

    (define (do-work work)
      (unless (future*-cond-wait? work)
        ;(printf "Worker ~a running future ~a\n" (worker-id worker) (future*-id work))
        ;(set-worker-count! worker (+ 1 (worker-count worker)))
        (current-future work)
        ((future*-engine work) TICKS (prefix work) complete (expire work worker)) ;; call engine.
        (current-future #f)))
    
    (loop)))

;; worker is attempting to steal work from peers or main thread
(define (steal-work worker)
  (define (pick-rand-worker)
    (define rand (random THREAD-COUNT))
    (define rand-worker (car (list-tail workers rand)))
    (if (eq? worker rand-worker)
        (pick-rand-worker)
        rand-worker))
  (define RETRY 2)
  (define workers (scheduler-workers global-scheduler))
  (define mtwork (steal (scheduler-queue global-scheduler)))
  (cond
    [(not (or (equal? mtwork 'Empty) (equal? mtwork 'Abort)))
     mtwork]
    [else
     (or (and (equal? mtwork 'Abort)
              (let try ()
                (set-worker-count! worker (+ 1 (worker-count worker)))
                (define work (steal (scheduler-queue global-scheduler)))
                (cond
                  [(equal? work 'Abort)
                   (set-worker-count! worker (+ 1 (worker-count worker)))
                   (try)]
                  [(not (equal? work 'Empty))
                   work]
                  [else
                   #f])))
         (let try ([victim (pick-rand-worker)]
                   [attempt 0])
           (cond
             [(< attempt (- THREAD-COUNT 1))
              (define work (steal (worker-queue victim)))
              (cond
                [(equal? work 'Empty)
                 (try (pick-rand-worker)
                      (+ 1 attempt))]
                [(equal? work 'Abort)
                 (let inner ([a 0])
                   (cond
                     [(< a RETRY)
                      (define work (steal (worker-queue victim)))
                      (cond
                        [(equal? work 'Empty)
                         (try (pick-rand-worker)
                              (+ 1 attempt))]
                        [(equal? work 'Abort)
                         (inner (+ 1 a))]
                        [else
                         work])]
                     [else
                      (try (pick-rand-worker)
                           (+ 1 attempt))]))]
                [else 
                 work])]
             [else
              #f])))]))

;; ----------------------------------------

(define (reset-future-logs-for-tracing!)
  (void))

(define (mark-future-trace-end!)
  (void))
