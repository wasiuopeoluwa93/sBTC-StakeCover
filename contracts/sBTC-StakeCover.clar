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


(define-public (unstake-from-pool (pool-id uint) (amount uint))
    (let
        ((pool (unwrap! (map-get? InsurancePools { pool-id: pool-id }) ERR-POOL-NOT-FOUND))
         (stake (unwrap! (map-get? PoolStakes { pool-id: pool-id, staker: tx-sender }) ERR-UNAUTHORIZED))
         (staker-total (unwrap! (map-get? StakerTotalStake { staker: tx-sender }) ERR-UNAUTHORIZED)))

        (asserts! (is-eq (get status pool) POOL-ACTIVE) ERR-INVALID-POOL-STATE)
        (asserts! (>= (get amount stake) amount) ERR-INSUFFICIENT-BALANCE)

        ;; Transfer stake back
        (as-contract (try! (stx-transfer? amount tx-sender tx-sender)))

        ;; Update pool stakes
        (map-set PoolStakes
            { pool-id: pool-id, staker: tx-sender }
            {
                amount: (- (get amount stake) amount),
                rewards: (get rewards stake),
                last-reward-height: stacks-block-height
            })

        ;; Update total stakes
        (map-set InsurancePools
            { pool-id: pool-id }
            (merge pool {
                total-staked: (- (get total-staked pool) amount)
            }))

        (map-set StakerTotalStake
            { staker: tx-sender }
            { total-stake: (- (get total-stake staker-total) amount) })

        (var-set total-staked (- (var-get total-staked) amount))
        (ok true)))

;; Claim Management Functions
(define-public (submit-claim 
    (pool-id uint) 
    (amount uint)
    (evidence (string-ascii 256)))
    (let
        ((claim-id (+ (var-get next-claim-id) u1))
         (pool (unwrap! (map-get? InsurancePools { pool-id: pool-id }) ERR-POOL-NOT-FOUND)))

        (asserts! (is-eq (get status pool) POOL-ACTIVE) ERR-INVALID-POOL-STATE)
        (asserts! (<= amount (get coverage-limit pool)) ERR-INVALID-AMOUNT)

        ;; Create claim
        (map-set InsuranceClaims
            { claim-id: claim-id }
            {
                pool-id: pool-id,
                claimer: tx-sender,
                amount: amount,
                evidence: evidence,
                status: CLAIM-PENDING,
                yes-votes: u0,
                no-votes: u0,
                voters: (list ),
                claim-height: stacks-block-height,
                voting-end-height: (+ stacks-block-height VOTING-PERIOD)
            })

        ;; Update counters
        (var-set next-claim-id claim-id)
        (map-set InsurancePools
            { pool-id: pool-id }
            (merge pool {
                claim-count: (+ (get claim-count pool) u1)
            }))

        (ok claim-id)))

(define-public (vote-on-claim (claim-id uint) (approve bool))
    (let
        ((claim (unwrap! (map-get? InsuranceClaims { claim-id: claim-id }) ERR-CLAIM-NOT-FOUND))
         (stake (unwrap! (map-get? PoolStakes 
            { pool-id: (get pool-id claim), staker: tx-sender }) ERR-UNAUTHORIZED)))

        (asserts! (< stacks-block-height (get voting-end-height claim)) ERR-VOTING-CLOSED)
        (asserts! (is-eq (get status claim) CLAIM-PENDING) ERR-INVALID-POOL-STATE)
        (asserts! (not (is-some (index-of (get voters claim) tx-sender))) ERR-ALREADY-VOTED)

        ;; Update votes
        (map-set InsuranceClaims
            { claim-id: claim-id }
            (merge claim {
                yes-votes: (if approve
                            (+ (get yes-votes claim) (get amount stake))
                            (get yes-votes claim)),
                no-votes: (if approve
                            (get no-votes claim)
                            (+ (get no-votes claim) (get amount stake))),
                voters: (unwrap! (as-max-len? 
                    (append (get voters claim) tx-sender) u100)
                    ERR-UNAUTHORIZED)
            }))
        (ok true)))

(define-public (process-claim (claim-id uint))
    (let
        ((claim (unwrap! (map-get? InsuranceClaims { claim-id: claim-id }) ERR-CLAIM-NOT-FOUND))
         (pool (unwrap! (map-get? InsurancePools { pool-id: (get pool-id claim) }) ERR-POOL-NOT-FOUND))
         (total-votes (+ (get yes-votes claim) (get no-votes claim))))

        (asserts! (>= stacks-block-height (get voting-end-height claim)) ERR-VOTING-CLOSED)
        (asserts! (is-eq (get status claim) CLAIM-PENDING) ERR-INVALID-POOL-STATE)
        (asserts! (>= total-votes MIN-VOTES-REQUIRED) ERR-INSUFFICIENT-VOTES)

        (if (>= (* (get yes-votes claim) u10) (* total-votes APPROVAL-THRESHOLD))
            (begin
                ;; Pay out claim
                (as-contract (try! (stx-transfer? 
                    (get amount claim) 
                    tx-sender 
                    (get claimer claim))))

                ;; Update claim status
                (map-set InsuranceClaims
                    { claim-id: claim-id }
                    (merge claim { status: CLAIM-PAID })))
            ;; Reject claim
            (map-set InsuranceClaims
                { claim-id: claim-id }
                (merge claim { status: CLAIM-REJECTED })))
        (ok true)))




(define-public (stake-in-pool (pool-id uint) (amount uint))
    (let
        ((pool (unwrap! (map-get? InsurancePools { pool-id: pool-id }) ERR-POOL-NOT-FOUND))
         (current-stake (default-to { amount: u0, rewards: u0, last-reward-height: stacks-block-height }
            (map-get? PoolStakes { pool-id: pool-id, staker: tx-sender })))
         (staker-total (default-to { total-stake: u0 }
            (map-get? StakerTotalStake { staker: tx-sender }))))

        (asserts! (is-eq (get status pool) POOL-ACTIVE) ERR-INVALID-POOL-STATE)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)

        ;; Transfer stake
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

        ;; Update pool stakes
        (map-set PoolStakes
            { pool-id: pool-id, staker: tx-sender }
            {
                amount: (+ (get amount current-stake) amount),
                rewards: (get rewards current-stake),
                last-reward-height: stacks-block-height
            })

        ;; Update total stakes
        (map-set InsurancePools
            { pool-id: pool-id }
            (merge pool {
                total-staked: (+ (get total-staked pool) amount)
            }))

        (map-set StakerTotalStake
            { staker: tx-sender }
            { total-stake: (+ (get total-stake staker-total) amount) })

        (var-set total-staked (+ (var-get total-staked) amount))
        (ok true)))

