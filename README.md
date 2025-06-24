#  Decentralized Insurance Protocol – Smart Contract

This is a Clarity smart contract for a **decentralized insurance pool** on the Stacks blockchain. It allows users to create insurance pools, stake STX, submit and vote on claims, and receive payouts based on democratic consensus.

---

## 🧾 Overview

This smart contract facilitates:

* Creation of insurance pools by the contract owner
* Users staking into insurance pools
* Submission of insurance claims by pool participants
* Community-based voting to approve or reject claims
* Automatic payout of approved claims
* Transparent and immutable records of claims, votes, and pool data

---

## 📜 Smart Contract Structure

### 🔐 Constants

* **Ownership and Errors**
  `CONTRACT-OWNER`, error constants like `ERR-UNAUTHORIZED`, etc.

* **Pool and Claim Status**
  E.g., `POOL-ACTIVE`, `CLAIM-PENDING`, `CLAIM-PAID`.

* **Governance Settings**
  Voting duration (`VOTING-PERIOD`), minimum votes, and approval threshold.

---

## 🧱 Data Maps

* `InsurancePools`: Stores metadata for each insurance pool.
* `PoolStakes`: Maps user stakes within a specific pool.
* `InsuranceClaims`: Tracks submitted claims and voting data.
* `StakerTotalStake`: Aggregated stake of each user across pools.

---

## 🔧 Public Functions

### 📌 Pool Management

* **`create-insurance-pool(name, coverage-limit, premium-rate)`**
  Admin function to initialize a new pool.

* **`stake-in-pool(pool-id, amount)`**
  Stake STX tokens into a specific pool.

* **`unstake-from-pool(pool-id, amount)`**
  Withdraw staked STX from a pool.

### 🧾 Claim Handling

* **`submit-claim(pool-id, amount, evidence)`**
  Submit a claim with relevant evidence (string).

* **`vote-on-claim(claim-id, approve)`**
  Stakeholders vote on claims; votes weighted by stake amount.

* **`process-claim(claim-id)`**
  Concludes voting and either pays out or rejects the claim.

---

## 📚 Read-Only Functions

* **`get-pool-info(pool-id)`**
  Returns pool metadata.

* **`get-stake-info(pool-id, staker)`**
  Returns a staker’s data within a pool.

* **`get-claim-info(claim-id)`**
  Returns detailed info about a specific claim.

* **`get-staker-total(staker)`**
  Returns a user’s total stake across all pools.

---

## ✅ Governance Logic

* Voting period lasts \~24 hours (`VOTING-PERIOD`).
* Minimum of 10 votes (`MIN-VOTES-REQUIRED`) required for quorum.
* 70% or more votes needed to approve a claim (`APPROVAL-THRESHOLD`).

---

## 🔒 Access Control

* Only the `CONTRACT-OWNER` can create new insurance pools.
* Claim submission and voting are permissionless (given pool membership).

---

## 🚧 Future Considerations

* Reward distribution mechanics
* Pool pausing by DAO vote
* Automated premium collection and policy expiration
* Dispute resolution layer
* UI integration and identity verification for claimants

---

##  Deployment Requirements

* Stacks blockchain
* Clarity-compatible environment (e.g., Clarinet or Hiro Wallet)
* STX tokens for staking and testing

---
