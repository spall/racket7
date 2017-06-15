;; Futures API

(define ID 1)

(define id-lock (make-lock #f))

(define (get-next-id)
  (lock-acquire id-lock)
  (let ([id ID])
    (set! ID (+ 1 id))
    (lock-release id-lock)
    id))

(define-record-type (future* make-future future?)
    (fields id would-be? (mutable thunk) (mutable engine) 
	    (mutable result) (mutable done?) cond lock (mutable blocked?)
	    (mutable resumed?) (mutable cont) (mutable prompt)))
;; future? defined by record.

(define (futures-enabled?)
  (threaded?))

#| Chez doesn't seem to have a built in function that does this.
Can call out to C in chez, so maybe can just duplicate what
racket currently does in C.
|#
(define (processor-count)
  1)

(define current-future (internal-make-thread-parameter #f))

(meta-cond
 [(threaded?)

  (define (thunk-wrapper f thunk)
    (define p (make-continuation-prompt-tag 'future))
    (future*-prompt-set! f p)
    (lambda ()
      (call-with-continuation-prompt
       (lambda ()
	 (let ([result (thunk)])
	   (lock-acquire (future*-lock f))
	   (future*-result-set! f result)
	   (future*-done?-set! f #t)
	   (condition-signal (future*-cond f))
	   (lock-release (future*-lock f))))
       p)))

  (define (future thunk)
    (unless (scheduler-running?)
	    (start-scheduler))
    
    (let* ([f (make-future (get-next-id) #f (void) (void) (void) 
			   #f (make-condition) (make-lock #f) #f
			   #f #f (void))]
	   [th (thunk-wrapper f thunk)])
      (future*-engine-set! f (make-engine th #f #t))
      (schedule-future f)
      f))

  (define (would-be-future thunk)
    (let* ([f (make-future (get-next-id) #t (void) (void) (void) 
			   #f (void) (make-lock #f) #f
			   #f #f (void))]
	   [th (thunk-wrapper f thunk)])
      (future*-thunk-set! f th)
      f))

  (define (touch f)
    (cond
     [(future*-would-be? f)
      ((future*-thunk f))
      (future*-result f)]
     [(future*-blocked? f)
     (lock-acquire (future*-lock f)) ;; if we acquire lock. cont is either set or not. 
     (unless  (future*-cont f) ;; then it hasn't been set yet and need to block
	      (condition-wait (future*-cond f) (future*-lock f)))
      (future*-blocked?-set! f #f)
      (future*-resumed?-set! f #t)
      (lock-release (future*-lock f))
      (apply-continuation (future*-cont f) '())
      (future*-result f)]
     [(future*-done? f)
      (future*-result f)]
     [(future? (current-future)) ;; are we running in a future?
      (touch f)]
     [(lock-acquire (future*-lock f) #f)
      (condition-wait (future*-cond f) (future*-lock f))
      (lock-release (future*-lock f))
      (future-awoken f)] ;; acquired 
     [else
      (touch f)])) ;; not acquired. might be writing result now.

  (define (future-awoken f)
    (cond
     [(future*-done? f)
      (future*-result f)]
     [(future*-blocked? f) ;; do I need to check here? I don't believe so. only 2 places signals happen
      (lock-acquire (future*-lock f))
      (future*-blocked?-set! f #f)
      (future*-resumed?-set! f #t)
      (lock-release (future*-lock f))
      (apply-continuation (future*-cont f) '())
      (future*-result f)]
     [else
      (error 'touch "Awoken in touch but future is neither done nor blocked\n")]))

  (define (block)
    (define f (current-future))
    (when (and f (not (future*-blocked? f))
	       (not (future*-resumed? f)))
	  (lock-acquire (future*-lock f))
	  (future*-blocked?-set! f #t)
	  (lock-release (future*-lock f))
	  (engine-block)))
  
  ]
 [else
  ;; not threaded
  
  (define (thunk-wrapper f thunk)
    (lambda ()
      (let ([result (thunk)])
	(future*-result-set! f result)
	(future*-done?-set! f #t) )))

  (define (future thunk)
    (would-be-future thunk))

  (define (would-be-future thunk)
    (let* ([f (make-future (get-next-id) #t (void) (void) (void) 
			   #f (void) (make-lock #f) #f
			   #f #f (void))]
	   [th (thunk-wrapper f thunk)])
      (future*-thunk-set! f th)
      f))

  (define (touch f)
    ((future*-thunk f))
    (future*-result f))

  ])
