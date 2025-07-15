;; CarbonX - Carbon Credit Trading Contract
;; A smart contract for trading verified carbon offset certificates on Stacks blockchain

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-not-verified (err u104))
(define-constant err-already-verified (err u105))
(define-constant err-invalid-price (err u106))
(define-constant err-self-trade (err u107))
(define-constant err-not-for-sale (err u108))

;; Data Variables
(define-data-var next-certificate-id uint u1)
(define-data-var platform-fee-percentage uint u250) ;; 2.5%

;; Data Maps
(define-map certificates
  uint
  {
    issuer: principal,
    project-name: (string-ascii 100),
    project-location: (string-ascii 100),
    carbon-amount: uint, ;; in tons CO2
    verification-standard: (string-ascii 50),
    issuance-date: uint,
    expiry-date: uint,
    verified: bool,
    retired: bool
  }
)

(define-map certificate-ownership
  uint
  principal
)

(define-map user-balances
  principal
  uint
)

(define-map marketplace-listings
  uint
  {
    seller: principal,
    price: uint, ;; in microSTX
    listed-at: uint
  }
)

(define-map verifiers
  principal
  bool
)

;; Read-only functions
(define-read-only (get-certificate (certificate-id uint))
  (map-get? certificates certificate-id)
)

(define-read-only (get-certificate-owner (certificate-id uint))
  (map-get? certificate-ownership certificate-id)
)

(define-read-only (get-user-balance (user principal))
  (default-to u0 (map-get? user-balances user))
)

(define-read-only (get-marketplace-listing (certificate-id uint))
  (map-get? marketplace-listings certificate-id)
)

(define-read-only (is-verifier (user principal))
  (default-to false (map-get? verifiers user))
)

(define-read-only (get-platform-fee-percentage)
  (var-get platform-fee-percentage)
)

(define-read-only (get-next-certificate-id)
  (var-get next-certificate-id)
)

(define-read-only (calculate-platform-fee (amount uint))
  (/ (* amount (var-get platform-fee-percentage)) u10000)
)

;; Private functions
(define-private (is-certificate-owner (certificate-id uint) (user principal))
  (is-eq (some user) (map-get? certificate-ownership certificate-id))
)

(define-private (transfer-certificate (certificate-id uint) (from principal) (to principal))
  (begin
    (asserts! (is-certificate-owner certificate-id from) err-owner-only)
    (map-set certificate-ownership certificate-id to)
    (map-set user-balances from (- (get-user-balance from) u1))
    (map-set user-balances to (+ (get-user-balance to) u1))
    (ok true)
  )
)

;; Public functions

;; Owner functions
(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set verifiers verifier true)
    (ok true)
  )
)

(define-public (remove-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set verifiers verifier false)
    (ok true)
  )
)

(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee u1000) err-invalid-amount) ;; Max 10%
    (var-set platform-fee-percentage new-fee)
    (ok true)
  )
)

;; Certificate management
(define-public (issue-certificate 
  (project-name (string-ascii 100))
  (project-location (string-ascii 100))
  (carbon-amount uint)
  (verification-standard (string-ascii 50))
  (expiry-date uint)
)
  (let
    (
      (certificate-id (var-get next-certificate-id))
      (current-block-height block-height)
    )
    (asserts! (> carbon-amount u0) err-invalid-amount)
    (asserts! (> expiry-date current-block-height) err-invalid-amount)
    
    (map-set certificates certificate-id
      {
        issuer: tx-sender,
        project-name: project-name,
        project-location: project-location,
        carbon-amount: carbon-amount,
        verification-standard: verification-standard,
        issuance-date: current-block-height,
        expiry-date: expiry-date,
        verified: false,
        retired: false
      }
    )
    
    (map-set certificate-ownership certificate-id tx-sender)
    (map-set user-balances tx-sender (+ (get-user-balance tx-sender) u1))
    (var-set next-certificate-id (+ certificate-id u1))
    
    (ok certificate-id)
  )
)

(define-public (verify-certificate (certificate-id uint))
  (let
    (
      (certificate (unwrap! (map-get? certificates certificate-id) err-not-found))
    )
    (asserts! (is-verifier tx-sender) err-owner-only)
    (asserts! (is-eq (get verified certificate) false) err-already-verified)
    
    (map-set certificates certificate-id
      (merge certificate { verified: true })
    )
    
    (ok true)
  )
)

(define-public (retire-certificate (certificate-id uint))
  (let
    (
      (certificate (unwrap! (map-get? certificates certificate-id) err-not-found))
    )
    (asserts! (is-certificate-owner certificate-id tx-sender) err-owner-only)
    (asserts! (get verified certificate) err-not-verified)
    
    ;; Remove from marketplace if listed
    (map-delete marketplace-listings certificate-id)
    
    (map-set certificates certificate-id
      (merge certificate { retired: true })
    )
    
    (ok true)
  )
)

;; Marketplace functions
(define-public (list-certificate-for-sale (certificate-id uint) (price uint))
  (let
    (
      (certificate (unwrap! (map-get? certificates certificate-id) err-not-found))
    )
    (asserts! (is-certificate-owner certificate-id tx-sender) err-owner-only)
    (asserts! (get verified certificate) err-not-verified)
    (asserts! (is-eq (get retired certificate) false) err-not-found)
    (asserts! (> price u0) err-invalid-price)
    
    (map-set marketplace-listings certificate-id
      {
        seller: tx-sender,
        price: price,
        listed-at: block-height
      }
    )
    
    (ok true)
  )
)

(define-public (remove-certificate-from-sale (certificate-id uint))
  (let
    (
      (listing (unwrap! (map-get? marketplace-listings certificate-id) err-not-found))
    )
    (asserts! (is-eq (get seller listing) tx-sender) err-owner-only)
    
    (map-delete marketplace-listings certificate-id)
    
    (ok true)
  )
)

(define-public (buy-certificate (certificate-id uint))
  (let
    (
      (listing (unwrap! (map-get? marketplace-listings certificate-id) err-not-for-sale))
      (certificate (unwrap! (map-get? certificates certificate-id) err-not-found))
      (seller (get seller listing))
      (price (get price listing))
      (platform-fee (calculate-platform-fee price))
      (seller-amount (- price platform-fee))
    )
    (asserts! (not (is-eq tx-sender seller)) err-self-trade)
    (asserts! (get verified certificate) err-not-verified)
    (asserts! (is-eq (get retired certificate) false) err-not-found)
    
    ;; Transfer STX payment
    (try! (stx-transfer? seller-amount tx-sender seller))
    (try! (stx-transfer? platform-fee tx-sender contract-owner))
    
    ;; Transfer certificate ownership
    (try! (transfer-certificate certificate-id seller tx-sender))
    
    ;; Remove from marketplace
    (map-delete marketplace-listings certificate-id)
    
    (ok true)
  )
)

;; Direct transfer (for gifts or off-market trades)
(define-public (transfer-certificate-to (certificate-id uint) (recipient principal))
  (let
    (
      (certificate (unwrap! (map-get? certificates certificate-id) err-not-found))
    )
    (asserts! (is-certificate-owner certificate-id tx-sender) err-owner-only)
    (asserts! (not (is-eq tx-sender recipient)) err-self-trade)
    (asserts! (is-eq (get retired certificate) false) err-not-found)
    
    ;; Remove from marketplace if listed
    (map-delete marketplace-listings certificate-id)
    
    (try! (transfer-certificate certificate-id tx-sender recipient))
    
    (ok true)
  )
)