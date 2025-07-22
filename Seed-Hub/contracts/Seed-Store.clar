;; Decentralized Seed Marketplace Smart Contract
;; A comprehensive marketplace for buying and selling seeds with quality assurance

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-INSUFFICIENT-FUNDS (err u102))
(define-constant ERR-UNAUTHORIZED (err u103))
(define-constant ERR-INVALID-AMOUNT (err u104))
(define-constant ERR-ALREADY-EXISTS (err u105))
(define-constant ERR-INVALID-STATUS (err u106))
(define-constant ERR-EXPIRED (err u107))
(define-constant ERR-INVALID-RATING (err u108))
(define-constant ERR-ALREADY-RATED (err u109))
(define-constant ERR-DISPUTE-EXISTS (err u110))
(define-constant ERR-INVALID-RESOLUTION (err u111))
(define-constant ERR-INVALID-INPUT (err u112))

;; Order statuses
(define-constant STATUS-ACTIVE u0)
(define-constant STATUS-SOLD u1)
(define-constant STATUS-SHIPPED u2)
(define-constant STATUS-DELIVERED u3)
(define-constant STATUS-COMPLETED u4)
(define-constant STATUS-DISPUTED u5)
(define-constant STATUS-CANCELLED u6)

;; Data Variables
(define-data-var next-listing-id uint u1)
(define-data-var next-order-id uint u1)
(define-data-var next-dispute-id uint u1)
(define-data-var marketplace-fee-rate uint u250) ;; 2.5% (basis points)
(define-data-var min-stake-amount uint u1000000) ;; 1 STX minimum stake

;; Data Maps
;; Seed listings
(define-map seed-listings
    { listing-id: uint }
    {
        seller: principal,
        seed-type: (string-ascii 50),
        variety: (string-ascii 50),
        description: (string-ascii 500),
        price-per-unit: uint,
        available-quantity: uint,
        germination-rate: uint, ;; Percentage (0-100)
        harvest-time: uint, ;; Days to harvest
        organic-certified: bool,
        created-at: uint,
        expires-at: uint,
        status: uint
    }
)

;; Purchase orders
(define-map orders
    { order-id: uint }
    {
        listing-id: uint,
        buyer: principal,
        seller: principal,
        quantity: uint,
        total-price: uint,
        shipping-address: (string-ascii 200),
        created-at: uint,
        shipped-at: (optional uint),
        delivered-at: (optional uint),
        status: uint
    }
)

;; Seller profiles and ratings
(define-map seller-profiles
    { seller: principal }
    {
        total-sales: uint,
        total-ratings: uint,
        average-rating: uint, ;; Scaled by 100 (e.g., 450 = 4.5 stars)
        stake-amount: uint,
        reputation-score: uint,
        joined-at: uint
    }
)

;; Individual ratings
(define-map ratings
    { order-id: uint, rater: principal }
    {
        rating: uint, ;; 1-5 stars
        review: (string-ascii 500),
        created-at: uint
    }
)

;; Disputes
(define-map disputes
    { dispute-id: uint }
    {
        order-id: uint,
        complainant: principal,
        respondent: principal,
        reason: (string-ascii 500),
        evidence: (string-ascii 1000),
        created-at: uint,
        resolved-at: (optional uint),
        resolution: (optional (string-ascii 500)),
        resolved-by: (optional principal)
    }
)

;; Escrow balances
(define-map escrow-balances
    { order-id: uint }
    { amount: uint }
)

;; Seller stakes
(define-map seller-stakes
    { seller: principal }
    { amount: uint }
)

;; Input validation functions

;; Validate string inputs are not empty
(define-private (is-valid-string (input (string-ascii 1000)))
    (> (len input) u0)
)

;; Validate uint inputs are within reasonable bounds
(define-private (is-valid-uint (input uint) (min-val uint) (max-val uint))
    (and (>= input min-val) (<= input max-val))
)

;; Validate listing ID exists and is valid
(define-private (is-valid-listing-id (listing-id uint))
    (and 
        (> listing-id u0)
        (< listing-id (var-get next-listing-id))
        (is-some (map-get? seed-listings { listing-id: listing-id }))
    )
)

;; Validate order ID exists and is valid
(define-private (is-valid-order-id (order-id uint))
    (and 
        (> order-id u0)
        (< order-id (var-get next-order-id))
        (is-some (map-get? orders { order-id: order-id }))
    )
)

;; Validate dispute ID exists and is valid
(define-private (is-valid-dispute-id (dispute-id uint))
    (and 
        (> dispute-id u0)
        (< dispute-id (var-get next-dispute-id))
        (is-some (map-get? disputes { dispute-id: dispute-id }))
    )
)

;; Read-only functions

;; Get listing details
(define-read-only (get-listing (listing-id uint))
    (map-get? seed-listings { listing-id: listing-id })
)

;; Get order details
(define-read-only (get-order (order-id uint))
    (map-get? orders { order-id: order-id })
)

;; Get seller profile
(define-read-only (get-seller-profile (seller principal))
    (map-get? seller-profiles { seller: seller })
)

;; Get rating for an order by a specific rater
(define-read-only (get-rating (order-id uint) (rater principal))
    (map-get? ratings { order-id: order-id, rater: rater })
)

;; Get dispute details
(define-read-only (get-dispute (dispute-id uint))
    (map-get? disputes { dispute-id: dispute-id })
)

;; Get escrow balance for an order
(define-read-only (get-escrow-balance (order-id uint))
    (map-get? escrow-balances { order-id: order-id })
)

;; Get seller stake
(define-read-only (get-seller-stake (seller principal))
    (map-get? seller-stakes { seller: seller })
)

;; Get marketplace fee rate
(define-read-only (get-marketplace-fee-rate)
    (var-get marketplace-fee-rate)
)

;; Get minimum stake amount
(define-read-only (get-min-stake-amount)
    (var-get min-stake-amount)
)

;; Calculate marketplace fee
(define-read-only (calculate-marketplace-fee (amount uint))
    (/ (* amount (var-get marketplace-fee-rate)) u10000)
)

;; Public functions

;; Register as a seller with stake
(define-public (register-seller (stake-amount uint))
    (let (
        (current-stake (default-to u0 (get amount (map-get? seller-stakes { seller: tx-sender }))))
        (profile (map-get? seller-profiles { seller: tx-sender }))
        (validated-stake-amount stake-amount) ;; Use validated input
    )
        ;; Input validation
        (asserts! (is-valid-uint validated-stake-amount (var-get min-stake-amount) u1000000000000) ERR-INVALID-INPUT)
        (asserts! (>= validated-stake-amount (var-get min-stake-amount)) ERR-INVALID-AMOUNT)
        
        ;; Transfer stake to contract
        (try! (stx-transfer? validated-stake-amount tx-sender (as-contract tx-sender)))
        
        ;; Update stake amount
        (map-set seller-stakes
            { seller: tx-sender }
            { amount: (+ current-stake validated-stake-amount) }
        )
        
        ;; Create or update seller profile
        (match profile
            existing-profile
                (map-set seller-profiles
                    { seller: tx-sender }
                    (merge existing-profile { stake-amount: (+ (get stake-amount existing-profile) validated-stake-amount) })
                )
            (map-set seller-profiles
                { seller: tx-sender }
                {
                    total-sales: u0,
                    total-ratings: u0,
                    average-rating: u0,
                    stake-amount: validated-stake-amount,
                    reputation-score: u0,
                    joined-at: block-height
                }
            )
        )
        
        (ok true)
    )
)

;; Create a seed listing
(define-public (create-listing 
    (seed-type (string-ascii 50))
    (variety (string-ascii 50))
    (description (string-ascii 500))
    (price-per-unit uint)
    (available-quantity uint)
    (germination-rate uint)
    (harvest-time uint)
    (organic-certified bool)
    (expires-in-blocks uint)
)
    (let (
        (listing-id (var-get next-listing-id))
        (seller-profile (map-get? seller-profiles { seller: tx-sender }))
        ;; Validate and sanitize inputs
        (validated-seed-type seed-type)
        (validated-variety variety)
        (validated-description description)
        (validated-price price-per-unit)
        (validated-quantity available-quantity)
        (validated-germination germination-rate)
        (validated-harvest-time harvest-time)
        (validated-expires expires-in-blocks)
    )
        ;; Input validation
        (asserts! (is-valid-string validated-seed-type) ERR-INVALID-INPUT)
        (asserts! (is-valid-string validated-variety) ERR-INVALID-INPUT)
        (asserts! (is-valid-string validated-description) ERR-INVALID-INPUT)
        (asserts! (is-valid-uint validated-price u1 u1000000000000) ERR-INVALID-INPUT)
        (asserts! (is-valid-uint validated-quantity u1 u1000000000) ERR-INVALID-INPUT)
        (asserts! (is-valid-uint validated-germination u0 u100) ERR-INVALID-INPUT)
        (asserts! (is-valid-uint validated-harvest-time u1 u1000) ERR-INVALID-INPUT)
        (asserts! (is-valid-uint validated-expires u1 u1000000) ERR-INVALID-INPUT)
        
        ;; Business logic validation
        (asserts! (> validated-quantity u0) ERR-INVALID-AMOUNT)
        (asserts! (> validated-price u0) ERR-INVALID-AMOUNT)
        (asserts! (<= validated-germination u100) ERR-INVALID-RATING)
        (asserts! (> validated-expires u0) ERR-INVALID-AMOUNT)
        (asserts! (is-some seller-profile) ERR-UNAUTHORIZED)
        
        ;; Create listing
        (map-set seed-listings
            { listing-id: listing-id }
            {
                seller: tx-sender,
                seed-type: validated-seed-type,
                variety: validated-variety,
                description: validated-description,
                price-per-unit: validated-price,
                available-quantity: validated-quantity,
                germination-rate: validated-germination,
                harvest-time: validated-harvest-time,
                organic-certified: organic-certified,
                created-at: block-height,
                expires-at: (+ block-height validated-expires),
                status: STATUS-ACTIVE
            }
        )
        
        ;; Increment listing ID
        (var-set next-listing-id (+ listing-id u1))
        
        (ok listing-id)
    )
)

;; Purchase seeds
(define-public (purchase-seeds 
    (listing-id uint) 
    (quantity uint)
    (shipping-address (string-ascii 200))
)
    (let (
        (validated-listing-id listing-id)
        (validated-quantity quantity)
        (validated-address shipping-address)
        (listing (unwrap! (map-get? seed-listings { listing-id: validated-listing-id }) ERR-NOT-FOUND))
        (order-id (var-get next-order-id))
        (total-price (* (get price-per-unit listing) validated-quantity))
        (marketplace-fee (calculate-marketplace-fee total-price))
        (seller-amount (- total-price marketplace-fee))
    )
        ;; Input validation
        (asserts! (is-valid-listing-id validated-listing-id) ERR-INVALID-INPUT)
        (asserts! (is-valid-uint validated-quantity u1 u1000000000) ERR-INVALID-INPUT)
        (asserts! (is-valid-string validated-address) ERR-INVALID-INPUT)
        
        ;; Business logic validation
        (asserts! (is-eq (get status listing) STATUS-ACTIVE) ERR-INVALID-STATUS)
        (asserts! (>= (get available-quantity listing) validated-quantity) ERR-INSUFFICIENT-FUNDS)
        (asserts! (< block-height (get expires-at listing)) ERR-EXPIRED)
        (asserts! (> validated-quantity u0) ERR-INVALID-AMOUNT)
        
        ;; Transfer payment to escrow
        (try! (stx-transfer? total-price tx-sender (as-contract tx-sender)))
        
        ;; Store escrow balance
        (map-set escrow-balances
            { order-id: order-id }
            { amount: total-price }
        )
        
        ;; Create order
        (map-set orders
            { order-id: order-id }
            {
                listing-id: validated-listing-id,
                buyer: tx-sender,
                seller: (get seller listing),
                quantity: validated-quantity,
                total-price: total-price,
                shipping-address: validated-address,
                created-at: block-height,
                shipped-at: none,
                delivered-at: none,
                status: STATUS-SOLD
            }
        )
        
        ;; Update listing quantity
        (map-set seed-listings
            { listing-id: validated-listing-id }
            (merge listing { 
                available-quantity: (- (get available-quantity listing) validated-quantity),
                status: (if (is-eq (- (get available-quantity listing) validated-quantity) u0) STATUS-SOLD STATUS-ACTIVE)
            })
        )
        
        ;; Increment order ID
        (var-set next-order-id (+ order-id u1))
        
        (ok order-id)
    )
)

;; Mark order as shipped (seller only)
(define-public (mark-shipped (order-id uint))
    (let (
        (validated-order-id order-id)
        (order (unwrap! (map-get? orders { order-id: validated-order-id }) ERR-NOT-FOUND))
    )
        ;; Input validation
        (asserts! (is-valid-order-id validated-order-id) ERR-INVALID-INPUT)
        
        ;; Business logic validation
        (asserts! (is-eq tx-sender (get seller order)) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status order) STATUS-SOLD) ERR-INVALID-STATUS)
        
        (map-set orders
            { order-id: validated-order-id }
            (merge order {
                status: STATUS-SHIPPED,
                shipped-at: (some block-height)
            })
        )
        
        (ok true)
    )
)

;; Confirm delivery (buyer only)
(define-public (confirm-delivery (order-id uint))
    (let (
        (validated-order-id order-id)
        (order (unwrap! (map-get? orders { order-id: validated-order-id }) ERR-NOT-FOUND))
        (escrow (unwrap! (map-get? escrow-balances { order-id: validated-order-id }) ERR-NOT-FOUND))
        (marketplace-fee (calculate-marketplace-fee (get total-price order)))
        (seller-amount (- (get total-price order) marketplace-fee))
    )
        ;; Input validation
        (asserts! (is-valid-order-id validated-order-id) ERR-INVALID-INPUT)
        
        ;; Business logic validation
        (asserts! (is-eq tx-sender (get buyer order)) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status order) STATUS-SHIPPED) ERR-INVALID-STATUS)
        
        ;; Release payment to seller
        (try! (as-contract (stx-transfer? seller-amount tx-sender (get seller order))))
        
        ;; Transfer marketplace fee to contract owner
        (try! (as-contract (stx-transfer? marketplace-fee tx-sender CONTRACT-OWNER)))
        
        ;; Clear escrow
        (map-delete escrow-balances { order-id: validated-order-id })
        
        ;; Update order status
        (map-set orders
            { order-id: validated-order-id }
            (merge order {
                status: STATUS-DELIVERED,
                delivered-at: (some block-height)
            })
        )
        
        ;; Update seller profile
        (let (
            (seller-profile (unwrap! (map-get? seller-profiles { seller: (get seller order) }) ERR-NOT-FOUND))
        )
            (map-set seller-profiles
                { seller: (get seller order) }
                (merge seller-profile {
                    total-sales: (+ (get total-sales seller-profile) u1)
                })
            )
        )
        
        (ok true)
    )
)

;; Rate a completed order
(define-public (rate-order 
    (order-id uint) 
    (rating uint) 
    (review (string-ascii 500))
)
    (let (
        (validated-order-id order-id)
        (validated-rating rating)
        (validated-review review)
        (order (unwrap! (map-get? orders { order-id: validated-order-id }) ERR-NOT-FOUND))
        (existing-rating (map-get? ratings { order-id: validated-order-id, rater: tx-sender }))
    )
        ;; Input validation
        (asserts! (is-valid-order-id validated-order-id) ERR-INVALID-INPUT)
        (asserts! (is-valid-uint validated-rating u1 u5) ERR-INVALID-INPUT)
        (asserts! (is-valid-string validated-review) ERR-INVALID-INPUT)
        
        ;; Business logic validation
        (asserts! (and (>= validated-rating u1) (<= validated-rating u5)) ERR-INVALID-RATING)
        (asserts! (is-eq (get status order) STATUS-DELIVERED) ERR-INVALID-STATUS)
        (asserts! (or (is-eq tx-sender (get buyer order)) (is-eq tx-sender (get seller order))) ERR-UNAUTHORIZED)
        (asserts! (is-none existing-rating) ERR-ALREADY-RATED)
        
        ;; Store rating
        (map-set ratings
            { order-id: validated-order-id, rater: tx-sender }
            {
                rating: validated-rating,
                review: validated-review,
                created-at: block-height
            }
        )
        
        ;; Update seller's average rating if buyer is rating
        (if (is-eq tx-sender (get buyer order))
            (let (
                (seller-profile (unwrap! (map-get? seller-profiles { seller: (get seller order) }) ERR-NOT-FOUND))
                (current-total (get total-ratings seller-profile))
                (current-avg (get average-rating seller-profile))
                (new-total (+ current-total u1))
                (new-avg (/ (+ (* current-avg current-total) (* validated-rating u100)) new-total))
            )
                (map-set seller-profiles
                    { seller: (get seller order) }
                    (merge seller-profile {
                        total-ratings: new-total,
                        average-rating: new-avg,
                        reputation-score: (+ (get reputation-score seller-profile) validated-rating)
                    })
                )
            )
            true
        )
        
        (ok true)
    )
)

;; Create a dispute
(define-public (create-dispute 
    (order-id uint) 
    (reason (string-ascii 500))
    (evidence (string-ascii 1000))
)
    (let (
        (validated-order-id order-id)
        (validated-reason reason)
        (validated-evidence evidence)
        (order (unwrap! (map-get? orders { order-id: validated-order-id }) ERR-NOT-FOUND))
        (dispute-id (var-get next-dispute-id))
    )
        ;; Input validation
        (asserts! (is-valid-order-id validated-order-id) ERR-INVALID-INPUT)
        (asserts! (is-valid-string validated-reason) ERR-INVALID-INPUT)
        (asserts! (is-valid-string validated-evidence) ERR-INVALID-INPUT)
        
        ;; Business logic validation
        (asserts! (or (is-eq tx-sender (get buyer order)) (is-eq tx-sender (get seller order))) ERR-UNAUTHORIZED)
        (asserts! (not (is-eq (get status order) STATUS-DISPUTED)) ERR-DISPUTE-EXISTS)
        
        ;; Create dispute
        (map-set disputes
            { dispute-id: dispute-id }
            {
                order-id: validated-order-id,
                complainant: tx-sender,
                respondent: (if (is-eq tx-sender (get buyer order)) (get seller order) (get buyer order)),
                reason: validated-reason,
                evidence: validated-evidence,
                created-at: block-height,
                resolved-at: none,
                resolution: none,
                resolved-by: none
            }
        )
        
        ;; Update order status
        (map-set orders
            { order-id: validated-order-id }
            (merge order { status: STATUS-DISPUTED })
        )
        
        ;; Increment dispute ID
        (var-set next-dispute-id (+ dispute-id u1))
        
        (ok dispute-id)
    )
)

;; Resolve dispute (contract owner only)
(define-public (resolve-dispute 
    (dispute-id uint) 
    (resolution (string-ascii 500))
    (refund-to-buyer bool)
)
    (let (
        (validated-dispute-id dispute-id)
        (validated-resolution resolution)
        (dispute (unwrap! (map-get? disputes { dispute-id: validated-dispute-id }) ERR-NOT-FOUND))
        (order-id (get order-id dispute))
        (order (unwrap! (map-get? orders { order-id: order-id }) ERR-NOT-FOUND))
        (escrow (unwrap! (map-get? escrow-balances { order-id: order-id }) ERR-NOT-FOUND))
    )
        ;; Input validation
        (asserts! (is-valid-dispute-id validated-dispute-id) ERR-INVALID-INPUT)
        (asserts! (is-valid-string validated-resolution) ERR-INVALID-INPUT)
        
        ;; Business logic validation
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (asserts! (is-none (get resolved-at dispute)) ERR-INVALID-RESOLUTION)
        
        ;; Resolve payment based on decision
        (if refund-to-buyer
            ;; Refund to buyer
            (try! (as-contract (stx-transfer? (get amount escrow) tx-sender (get buyer order))))
            ;; Pay seller (minus marketplace fee)
            (let (
                (marketplace-fee (calculate-marketplace-fee (get amount escrow)))
                (seller-amount (- (get amount escrow) marketplace-fee))
            )
                (try! (as-contract (stx-transfer? seller-amount tx-sender (get seller order))))
                (try! (as-contract (stx-transfer? marketplace-fee tx-sender CONTRACT-OWNER)))
            )
        )
        
        ;; Clear escrow
        (map-delete escrow-balances { order-id: order-id })
        
        ;; Update dispute
        (map-set disputes
            { dispute-id: validated-dispute-id }
            (merge dispute {
                resolved-at: (some block-height),
                resolution: (some validated-resolution),
                resolved-by: (some tx-sender)
            })
        )
        
        ;; Update order status
        (map-set orders
            { order-id: order-id }
            (merge order { status: STATUS-COMPLETED })
        )
        
        (ok true)
    )
)

;; Withdraw seller stake
(define-public (withdraw-stake (amount uint))
    (let (
        (validated-amount amount)
        (current-stake (unwrap! (map-get? seller-stakes { seller: tx-sender }) ERR-NOT-FOUND))
        (remaining-stake (- (get amount current-stake) validated-amount))
    )
        ;; Input validation
        (asserts! (is-valid-uint validated-amount u1 u1000000000000) ERR-INVALID-INPUT)
        
        ;; Business logic validation
        (asserts! (>= (get amount current-stake) validated-amount) ERR-INSUFFICIENT-FUNDS)
        (asserts! (>= remaining-stake (var-get min-stake-amount)) ERR-INVALID-AMOUNT)
        
        ;; Transfer stake back to seller
        (try! (as-contract (stx-transfer? validated-amount tx-sender tx-sender)))
        
        ;; Update stake amount
        (map-set seller-stakes
            { seller: tx-sender }
            { amount: remaining-stake }
        )
        
        ;; Update seller profile
        (let (
            (seller-profile (unwrap! (map-get? seller-profiles { seller: tx-sender }) ERR-NOT-FOUND))
        )
            (map-set seller-profiles
                { seller: tx-sender }
                (merge seller-profile { stake-amount: remaining-stake })
            )
        )
        
        (ok true)
    )
)

;; Admin functions

;; Update marketplace fee rate (owner only)
(define-public (set-marketplace-fee-rate (new-rate uint))
    (let (
        (validated-rate new-rate)
    )
        ;; Input validation
        (asserts! (is-valid-uint validated-rate u0 u1000) ERR-INVALID-INPUT)
        
        ;; Business logic validation
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (asserts! (<= validated-rate u1000) ERR-INVALID-AMOUNT) ;; Max 10%
        
        (var-set marketplace-fee-rate validated-rate)
        (ok true)
    )
)

;; Update minimum stake amount (owner only)
(define-public (set-min-stake-amount (new-amount uint))
    (let (
        (validated-amount new-amount)
    )
        ;; Input validation
        (asserts! (is-valid-uint validated-amount u1 u1000000000000) ERR-INVALID-INPUT)
        
        ;; Business logic validation
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        
        (var-set min-stake-amount validated-amount)
        (ok true)
    )
)

;; Emergency functions

;; Cancel listing (seller only)
(define-public (cancel-listing (listing-id uint))
    (let (
        (validated-listing-id listing-id)
        (listing (unwrap! (map-get? seed-listings { listing-id: validated-listing-id }) ERR-NOT-FOUND))
    )
        ;; Input validation
        (asserts! (is-valid-listing-id validated-listing-id) ERR-INVALID-INPUT)
        
        ;; Business logic validation
        (asserts! (is-eq tx-sender (get seller listing)) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status listing) STATUS-ACTIVE) ERR-INVALID-STATUS)
        
        (map-set seed-listings
            { listing-id: validated-listing-id }
            (merge listing { status: STATUS-CANCELLED })
        )
        
        (ok true)
    )
)