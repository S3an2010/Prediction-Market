;; prediction-market.clar
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-market-closed (err u202))
(define-constant err-already-resolved (err u203))
(define-constant err-insufficient-funds (err u204))
(define-constant err-invalid-amount (err u205))
(define-constant err-market-not-resolved (err u206))
(define-constant err-already-claimed (err u207))
(define-constant err-not-winner (err u208))

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
    (end-block (+ block-height duration))
    (validated-question question)
    (validated-description description)
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> duration u0) err-invalid-amount)
    (asserts! (> (len validated-question) u0) err-invalid-amount)
    (asserts! (> (len validated-description) u0) err-invalid-amount)
    (map-set markets { market-id: market-id }
      {
        question: validated-question,
        description: validated-description,
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
    (validated-market-id market-id)
    (validated-prediction prediction)
  )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (< block-height (get end-block market)) err-market-closed)
    (asserts! (not (get resolved market)) err-already-resolved)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set positions { position-id: position-id }
      {
        trader: tx-sender,
        market-id: validated-market-id,
        prediction: validated-prediction,
        amount: amount,
        claimed: false
      }
    )
    (map-set markets { market-id: validated-market-id }
      (merge market {
        total-yes: (if validated-prediction (+ (get total-yes market) amount) (get total-yes market)),
        total-no: (if validated-prediction (get total-no market) (+ (get total-no market) amount))
      })
    )
    (var-set next-position-id (+ position-id u1))
    (ok position-id)
  )
)

(define-public (resolve-market (market-id uint) (outcome bool))
  (let (
    (market (unwrap! (map-get? markets { market-id: market-id }) err-not-found))
    (validated-market-id market-id)
    (validated-outcome outcome)
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (>= block-height (get end-block market)) err-market-closed)
    (asserts! (not (get resolved market)) err-already-resolved)
    (map-set markets { market-id: validated-market-id }
      (merge market { resolved: true, outcome: (some validated-outcome) })
    )
    (ok true)
  )
)

(define-public (claim-winnings (position-id uint))
  (let (
    (position (unwrap! (map-get? positions { position-id: position-id }) err-not-found))
    (market (unwrap! (map-get? markets { market-id: (get market-id position) }) err-not-found))
    (outcome (unwrap! (get outcome market) err-market-not-resolved))
    (validated-position-id position-id)
  )
    (asserts! (is-eq tx-sender (get trader position)) err-owner-only)
    (asserts! (get resolved market) err-market-not-resolved)
    (asserts! (not (get claimed position)) err-already-claimed)
    (asserts! (is-eq (get prediction position) outcome) err-not-winner)

    (let (
      (winning-pool (if outcome (get total-yes market) (get total-no market)))
      (total-pool (+ (get total-yes market) (get total-no market)))
      (payout (if (is-eq winning-pool u0) 
                u0 
                (/ (* (get amount position) total-pool) winning-pool)))
    )
      (asserts! (> payout u0) err-insufficient-funds)
      (try! (as-contract (stx-transfer? payout tx-sender (get trader position))))
      (map-set positions { position-id: validated-position-id }
        (merge position { claimed: true })
      )
      (ok payout)
    )
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

(define-read-only (calculate-payout (position-id uint))
  (let (
    (position (unwrap! (map-get? positions { position-id: position-id }) err-not-found))
    (market (unwrap! (map-get? markets { market-id: (get market-id position) }) err-not-found))
  )
    (if (get resolved market)
      (let (
        (outcome (unwrap! (get outcome market) err-market-not-resolved))
        (winning-pool (if outcome (get total-yes market) (get total-no market)))
        (total-pool (+ (get total-yes market) (get total-no market)))
      )
        (if (and (is-eq (get prediction position) outcome) (> winning-pool u0))
          (ok (/ (* (get amount position) total-pool) winning-pool))
          (ok u0)
        )
      )
      err-market-not-resolved
    )
  )
)

(define-read-only (get-next-market-id)
  (var-get next-market-id)
)

(define-read-only (get-next-position-id)
  (var-get next-position-id)
)