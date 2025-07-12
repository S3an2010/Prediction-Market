;; prediction-market.clar
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-market-closed (err u202))
(define-constant err-already-resolved (err u203))
(define-constant err-insufficient-funds (err u204))

(define-map markets
  { market-id: uint }
  {
    question: (string-ascii 200),
    description: (string-ascii 500),
    end-block: uint,
    resolved: bool,
    outcome: (optional bool),
    total-yes: uint,
    total-no: uint
  }
)

(define-map positions
  { position-id: uint }
  {
    trader: principal,
    market-id: uint,
    prediction: bool,
    amount: uint,
    claimed: bool
  }
)

(define-data-var next-market-id uint u1)
(define-data-var next-position-id uint u1)

(define-public (create-market (question (string-ascii 200)) (description (string-ascii 500)) (duration uint))
  (let (
    (market-id (var-get next-market-id))
    (end-block (+ stacks-block-height duration))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set markets { market-id: market-id }
      {
        question: question,
        description: description,
        end-block: end-block,
        resolved: false,
        outcome: none,
        total-yes: u0,
        total-no: u0
      }
    )
    (var-set next-market-id (+ market-id u1))
    (ok market-id)
  )
)

(define-public (buy-position (market-id uint) (prediction bool) (amount uint))
  (let (
    (position-id (var-get next-position-id))
    (market (unwrap! (map-get? markets { market-id: market-id }) err-not-found))
  )
    (asserts! (< stacks-block-height (get end-block market)) err-market-closed)
    (asserts! (not (get resolved market)) err-already-resolved)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

    (map-set positions { position-id: position-id }
      {
        trader: tx-sender,
        market-id: market-id,
        prediction: prediction,
        amount: amount,
        claimed: false
      }
    )

    (map-set markets { market-id: market-id }
      (merge market {
        total-yes: (if prediction (+ (get total-yes market) amount) (get total-yes market)),
        total-no: (if prediction (get total-no market) (+ (get total-no market) amount))
      })
    )

    (var-set next-position-id (+ position-id u1))
    (ok position-id)
  )
)

(define-public (resolve-market (market-id uint) (outcome bool))
  (let ((market (unwrap! (map-get? markets { market-id: market-id }) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (>= stacks-block-height (get end-block market)) err-market-closed)
    (asserts! (not (get resolved market)) err-already-resolved)

    (map-set markets { market-id: market-id }
      (merge market { resolved: true, outcome: (some outcome) })
    )
    (ok true)
  )
)

(define-read-only (get-market (market-id uint))
  (map-get? markets { market-id: market-id })
)

(define-read-only (get-position (position-id uint))
  (map-get? positions { position-id: position-id })
)

(define-read-only (get-market-odds (market-id uint))
  (let ((market (unwrap! (map-get? markets { market-id: market-id }) err-not-found)))
    (ok {
      yes-pool: (get total-yes market),
      no-pool: (get total-no market),
      total-pool: (+ (get total-yes market) (get total-no market))
    })
  )
)