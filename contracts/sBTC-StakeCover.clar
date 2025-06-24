;; DeFi Insurance Pool Contract
;; Implements pooled insurance with DAO governance for claims

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u1))
(define-constant ERR-INVALID-AMOUNT (err u2))
(define-constant ERR-INSUFFICIENT-BALANCE (err u3))
(define-constant ERR-POOL-NOT-FOUND (err u4))
(define-constant ERR-CLAIM-NOT-FOUND (err u5))
(define-constant ERR-INVALID-POOL-STATE (err u6))
(define-constant ERR-ALREADY-VOTED (err u7))
(define-constant ERR-VOTING-CLOSED (err u8))
(define-constant ERR-INSUFFICIENT-VOTES (err u9))

;; Pool status
(define-constant POOL-ACTIVE u1)
(define-constant POOL-PAUSED u2)
(define-constant POOL-LIQUIDATED u3)

;; Claim status
(define-constant CLAIM-PENDING u1)
(define-constant CLAIM-APPROVED u2)
(define-constant CLAIM-REJECTED u3)
(define-constant CLAIM-PAID u4)

;; Governance parameters
(define-constant VOTING-PERIOD u144) ;; ~24 hours in blocks
(define-constant MIN-VOTES-REQUIRED u10)
(define-constant APPROVAL-THRESHOLD u7) ;; 70% approval needed

;; Data Maps
(define-map InsurancePools
    { pool-id: uint }
    {
        name: (string-ascii 50),
        status: uint,
        total-staked: uint,
        coverage-limit: uint,
        premium-rate: uint,
        claim-count: uint,
        creation-height: uint
    }
)

(define-map PoolStakes
    { pool-id: uint, staker: principal }
    {
        amount: uint,
        rewards: uint,
        last-reward-height: uint
    }
)

(define-map InsuranceClaims
    { claim-id: uint }
    {
        pool-id: uint,
        claimer: principal,
        amount: uint,
        evidence: (string-ascii 256),
        status: uint,
        yes-votes: uint,
        no-votes: uint,
        voters: (list 100 principal),
        claim-height: uint,
        voting-end-height: uint
    }
)

(define-map StakerTotalStake
    { staker: principal }
    { total-stake: uint }
)

;; Variables
(define-data-var next-pool-id uint u0)
(define-data-var next-claim-id uint u0)
(define-data-var total-pools uint u0)
(define-data-var total-staked uint u0)


;; READ ONLY FUNCTIONS

;; Read-only functions
(define-read-only (get-pool-info (pool-id uint))
    (map-get? InsurancePools { pool-id: pool-id }))

(define-read-only (get-stake-info (pool-id uint) (staker principal))
    (map-get? PoolStakes { pool-id: pool-id, staker: staker }))

(define-read-only (get-claim-info (claim-id uint))
    (map-get? InsuranceClaims { claim-id: claim-id }))

(define-read-only (get-staker-total (staker principal))
    (map-get? StakerTotalStake { staker: staker }))



;; Pool Management Functions
(define-public (create-insurance-pool 
    (name (string-ascii 50))
    (coverage-limit uint)
    (premium-rate uint))
    (let
        ((pool-id (+ (var-get next-pool-id) u1)))

        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (asserts! (> coverage-limit u0) ERR-INVALID-AMOUNT)
        (asserts! (> premium-rate u0) ERR-INVALID-AMOUNT)

        (map-set InsurancePools
            { pool-id: pool-id }
            {
                name: name,
                status: POOL-ACTIVE,
                total-staked: u0,
                coverage-limit: coverage-limit,
                premium-rate: premium-rate,
                claim-count: u0,
                creation-height: stacks-block-height
            })

        (var-set next-pool-id pool-id)
        (var-set total-pools (+ (var-get total-pools) u1))
        (ok pool-id)))
