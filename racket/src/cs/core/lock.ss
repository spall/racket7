;; locking code for core-hash.ss

(define make-scheduler-lock (lambda () #f))
(define scheduler-lock-acquire (lambda (l) (void)))
(define scheduler-lock-release (lambda (l) (void)))

(define (set-scheduler-lock-callbacks! make acquire release)
  (set! make-scheduler-lock make)
  (set! scheduler-lock-acquire acquire)
  (set! scheduler-lock-release release))


(define make-scheduler-condition (lambda () #f))
(define scheduler-condition-wait (lambda (c) (void)))
(define scheduler-condition-signal (lambda (c) (void)))
(define scheduler-condition-broadcast (lambda (c) (void)))

(define (set-scheduler-condition-callbacks! make wait signal broadcast)
  (set! make-scheduler-condition make)
  (set! scheduler-condition-wait wait)
  (set! scheduler-condition-signal signal)
  (set! scheduler-condition-broadcast broadcast))

(define-record-type (f-cond f-make-condition f-condition?)
  (fields scond (mutable blocked-futures) lock))

;; already checked type
(define (f-condition-wait c m)
  (define cf (current-future))
  (unless (own-lock? m)
	  (error 'f-condition-wait "future does not hold mutex\n"))
  (when (and cf (future*-cond-wait? cf)) ;; fatal error
	(error 'f-condition-wait "future is already waiting on condition\n"))
  (lock-acquire (f-cond-lock c))
  (queue-add! (f-cond-blocked-futures c) cf)
  (lock-release (f-cond-lock c))
  (lock-relase m) 
  (future*-cond-wait?-set! cf #t) ;; do we need to acquire future's lock? m could have been future's lock
  (engine-block)
  (lock-acquire m))

(define (f-condition-signal c)
  (lock-acquire (f-cond-lock c))
  (unless (queue-empty? (f-cond-blocked-futures c)) ;; not empty
	  (let ([f (queue-remove! (f-cond-blocked-futures c))])
	    (future*-cond-wait?-set! f #f)))
  (lock-release (f-cond-lock c)))
	    
;; what about racing to wait and signal?
(define (f-condition-broadcast c) 
  (lock-acquire (f-cond-lock c))
  (let loop ()
    (unless (queue-empty? (f-cond-blocked-futures c)) ;; not empty
	    (let ([f (queue-remove! (f-cond-blocked-futures c))])
	      (future*-cond-wait?-set! f #f)
	      (loop))))
  (lock-release (f-cond-lock c))) 

;; What do I need condition to do?

;; Problem: Future might need to use real AND fake condition
;; fake condition COULD contain a real condition. But how would we know when to ignore real
;; condition and when to use it?
;; Could have flag that signalled when to use real or fake condition. BUT then this changes the API
;; which is maybe not a problem. since this code isn't going to be exported to the user.

(meta-cond
 [(guard (x [#t #t]) (eval 'make-mutex) #f)
  ;; Using a Chez Scheme build without thread support,
  ;; but we need to cooperate with engine-based threads.

  ;; `eqv?`- and `eq?`-based tables appear to run with
  ;; interrupts disabled, so they're safe for engine-based
  ;; threads; just create a Racket-visible lock for
  ;; `equal?`-based hash tables
  (define (make-lock for-kind)
    (and (eq? for-kind 'equal?)
         (make-scheduler-lock)))

  (define lock-acquire 
    (case-lambda ;; so it matches the one below
     [(lock)
      (when lock
	    ;; Thread layer sets this callback to wait
	    ;; on a semaphore:
	    (scheduler-lock-acquire lock))]
     [(lock _)
      (when lock
	    ;; Thread layer sets this callback to wait
	    ;; on a semaphore:
	    (scheduler-lock-acquire lock))]))

  (define (lock-release lock)
    (when lock
      (scheduler-lock-release lock)))

  (define make-condition make-scheduler-condition)
  (define (condition-wait c m)
    (lock-release m)
    (scheduler-condition wait c)
    (lock-acquire m))
  
  (define condition-signal scheduler-condition-signal)
  (define condition-broadcast scheduler-condition-broadcast)
  ]
 [else
  ;; Using a Chez Scheme build with thread support; make hash-table
  ;; access thread-safe at that level for `eq?`- and `eqv?`-based
  ;; tables; an `equal?`-based table is not thread-safe at that
  ;; level, because operations can take unbounded time, and then
  ;; the Racket scheduler could become blocked on a Chez-level mutex
  ;; in the same Chez-level thread.

  ;; Idea: instead of mutexes, which are relatively expansive, use
  ;;  https://lwn.net/Articles/590243/
  ;;  Synchronization Without Contention Mellor-Crummey Scott (MCS lock)
  #|
  (define-record mcs-spinlock (next locked?))

  (define (create-mcs-spinlock) (make-mcs-spinlock #f #f))
  |#

  (define-record-type (f-lock make-f-lock f-lock?)
    (fields ftptr (mutable owner)))
  
  ;; create own atomic region. TODO

  (define (cf-id)
    (if (not (current-future))
	#f
	(future*-id (current-future))))
  
    ;; An implementation I imagine would be more efficient is for
    ;; this function to engine-block and have the scheduler check
    ;; when the lock is available and then reschedule when that 
    ;; occurs rather than being occasionally scheduled by the scheduler and 
    ;; possibly only looping during that time
    ;; AND a lock with a queue so futures are more fairly given the lock. 
    ;; harder to implement (impossible?)  with current atomic operations
  (define (f-lock-acquire lock block?)
    (define rlock (f-lock-ftptr lock))
    (cond
     [(eq? (ftype-ref uptr () rlock) 1)
      (start-atomic)
      (fprintf (current-error-port) "future ~a Trying to acquire lock\n" (cf-id))
      (cond
       [(ftype-locked-decr! uptr () rlock) ;; acquired lock
	(fprintf (current-error-port) "Got lock\n")
	(f-lock-owner-set! lock (current-future))
	(end-atomic)
	#t]
       [(not block?)
	(ftype-locked-incr! uptr () rlock) ;; undo our increment
	(end-atomic)
	#f]
       [else ;; failed to acquire lock
	(ftype-locked-incr! uptr () rlock)
	(end-atomic)
	(f-lock-acquire lock block?)])]  ;; try again
     [(not block?)
      #f]
     [else ;; lock is already held so dont try to acquire
      (f-lock-acquire lock block?)]))

  (define (f-lock-release lock)
    ;; should this code error if one is true but not the other? below
    (when (and (eq? (current-future) (f-lock-owner lock)))
	      ; (> (ftype-ref uptr () (f-lock-ftptr lock)) -1))
	  (start-atomic)
	  (f-lock-owner-set! lock #t)
	  (ftype-locked-incr! uptr () (f-lock-ftptr lock))
	  (end-atomic)))

  (define (make-lock for-kind)
    (cond
     [(eq? for-kind 'equal?)
        (make-scheduler-lock)]
     [(eq? for-kind 'future)
      (make-f-lock (let ([l (make-ftype-pointer 
			     uptr ;; check that this is correct
			     (foreign-alloc (ftype-sizeof uptr)))])
		     (ftype-init-lock! uptr () l) ; set to 0
		     (ftype-locked-incr! uptr () l) ; set to 1
		     l) #t)]
     [else
      (make-mutex)]))

  (define lock-acquire
    (case-lambda
     [(lock)
      (cond
       [(mutex? lock)
	(mutex-acquire lock)]
       [(f-lock? lock)
	(f-lock-acquire lock #t)]
       [else
	(scheduler-lock-acquire lock)])]
     [(lock block?)
      (cond
       [(mutex? lock)
	  (mutex-acquire lock block?)]
       [(f-lock? lock)
	(f-lock-acquire lock block?)]
       [else
	(scheduler-lock-acquire lock)])]))
  
  (define (lock-release lock)
    (cond
     [(mutex? lock)
      (mutex-release lock)]
     [(f-lock? lock)
      (f-lock-release lock)]
     [else
      (scheduler-lock-release lock)]))

  ;; returns true if current-future owns lock
  (define (own-lock? lock)
    (eq? (current-future) (f-lock-owner lock)))

  ;; Conditions for futures
  (define (make-condition)
    (f-make-condition (make-scheduler-condition) (make-queue) (make-lock 'future)))

  ;; how to synchronize threads and futures together??????
  ;; they need to share locks. 

  ;; Have a future lock, which will be acquired by both a racket thread and a future. 
  ;; Scenario. 
  ;; future wants to write result to future. 
  ;; a racket thread wants to touch the future and therefore needs to acquire the future's lock
  ;; How do we let thread see that future has lock and vice-versa?

  ;; When future acquires lock, it uses atomic decrement to attempt to acquire lock
  ;; The lock is in a busy-loop which can jsut be descheduled by future scheduler which means
  ;; future acquiring lock does not block real thread. GOOD
  ;; also lock stores which future holds it. 

  ;; What we want a racket thread to do when it acquires a lock at this level is NOT block
  ;; the racket thraed scheduler. So just not block real thread like above.
  ;; So, if a rthread calls lock-acquire it needs to acquire the SAME lock as the future
  ;; so that either the rthread or the future holds the lock. 
  ;; so thread can call the same code as the future, but cannot use the atomics created
  ;; at this level. because they don't control the rthread scheduler. 


  (define (condition-wait c m)
    (unless (f-condition? c)
	    (error 'condition-wait "Expected a condition\n"))
    ;; TODO: check if future owns this lock. can do if we made the locks :)
    (cond
     [(not (current-future)) ;; thread wait. this condition check doesnt work
      (lock-release m)
      (scheduler-condition-wait c)
      (lock-acquire m)]
     [else
      (f-condition-wait c m)]))

  ;; regular condition-signal says it will wakeup some thread. So we will do the same
  ;; no guarantee about who will be awoken
  ;; will attempt to wake a real thread if there are no futures waiting.
  (define (condition-signal c)
    (unless (f-condition? c)
	    (error 'condition-signal "Expected a condition\n"))
    ;; how to know when to signal to a thread?
    (cond
     [(queue-empty? (f-cond-blocked-futures c))
      (scheduler-condition-signal c)]
     [else
      (f-condition-signal c)]))
  
  ;; first wake up any futures. Then wake up any threads.
  (define (condition-broadcast c)
    (unless (f-condition? c)
	    (error 'condition-broadcast "Expected a condition\n"))
    (scheduler-condition-broadcast c)
    (f-condition-broadcast c))


  ;; need conditions for threads.

  ;; extend interface racket gets from chez. provide a mutable vector with 1 element?
  ;; extend engine-block to take an optional argument.  passes that argument to an expire procedure
  ;; argument would give the thread scheduler a mutable variable. and scheduler owuldn't run
  ;; thread again until that mutable variable was true  or false.
  ;; just created a backchannel
  
  ;; touch passes mutable variable over this backchannel.
  ;; 

])


;; WHY can't a futures continuation be executed twice?


