# StarkStream

[![CI](https://github.com/ZengLLQ/stark-stream/actions/workflows/ci.yml/badge.svg)](https://github.com/ZengLLQ/stark-stream/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Cairo: 2.21](https://img.shields.io/badge/Cairo-2.21.0-orange.svg)](https://cairo-lang.org/)
[![Starknet](https://img.shields.io/badge/Starknet-Layer%202-blue.svg)](https://starknet.io/)

**StarkStream** is a continuous money streaming and cliff-vesting smart contract protocol written in Cairo 2.21 for Starknet. It enables continuous, real-time per-second token disbursements, milestone cliff releases, partial asynchronous withdrawals, and mutual cancellation with mathematical balance conservation guarantees.

---

## Mathematical Specification

### 1. Continuous Streaming Rate Function

For any stream initialized with total principal $D$, start timestamp $t_{\text{start}}$, stop timestamp $t_{\text{stop}}$, and cliff timestamp $t_{\text{cliff}} \in [t_{\text{start}}, t_{\text{stop}}]$, the cumulative unlocked balance $S(t)$ at block timestamp $t$ is defined as:

$$
S(t) = \begin{cases}
0, & t < t_{\text{start}} \lor t < t_{\text{cliff}} \\
D \cdot \left( \frac{t - t_{\text{start}}}{t_{\text{stop}} - t_{\text{start}}} \right), & t_{\text{cliff}} \le t < t_{\text{stop}} \\
D, & t \ge t_{\text{stop}}
\end{cases}
$$

### 2. Available Recipient Balance

Accounting for cumulative previous withdrawals $W(t)$:

$$
B_{\text{recipient}}(t) = \max\Big(0, S(t) - W(t)\Big)
$$

### 3. Sender Unvested Balance

The unvested funds available for refund upon stream cancellation:

$$
B_{\text{sender}}(t) = D - S(t)
$$

### 4. Conservation of Principal Invariant

At all timestamps $t \in [0, \infty)$:

$$
B_{\text{sender}}(t) + S(t) \equiv D
$$

And post-cancellation:

$$
\text{Refund}_{\text{sender}} + \text{Payout}_{\text{recipient}} + W_{\text{prior}} \equiv D
$$

Zero funds can be created, lost, or trapped in contract state.

---

## Protocol Lifecycle

```mermaid
sequenceDiagram
    autonumber
    actor Sender as Stream Creator (Employer / DAO)
    actor Recipient as Beneficiary
    participant Protocol as StarkStreamContract (Starknet)

    Sender->>Protocol: create_stream(recipient, deposit, start, stop, cliff)
    Protocol-->>Protocol: Register Stream & Emit StreamCreated

    Note over Sender,Recipient: Linear Streaming Window [t_start .. t_stop]
    alt Before Cliff (t < t_cliff)
        Recipient->>Protocol: recipient_balance_at(t)
        Protocol-->>Recipient: 0
    else Cliff Reached (t >= t_cliff)
        Recipient->>Protocol: withdraw_from_stream(stream_id, amount)
        Protocol-->>Protocol: Validate amount <= S(t) - W(t)
        Protocol->>Recipient: Transfer tokens
        Protocol-->>Recipient: Emit StreamWithdrawn
    end

    opt Mutual Cancellation
        Sender->>Protocol: cancel_stream(stream_id)
        Protocol-->>Protocol: Compute S(t_now) and D - S(t_now)
        Protocol->>Sender: Refund D - S(t_now)
        Protocol->>Recipient: Payout S(t_now) - W(t_now)
        Protocol-->>Sender: Emit StreamCancelled
    end
```

---

## Module Layout

```
src/
├── lib.cairo          # Module definitions and test harness entrypoint
├── types.cairo        # Stream storage structure and event payloads
├── math.cairo         # Exact per-second streaming and cliff tranche calculations
├── stark_stream.cairo # Starknet contract implementation (Storage, Map, and ABI)
└── tests.cairo        # Comprehensive unit tests verifying linear rate, cliff, and invariants
Scarb.toml             # Cairo 2.21 compiler and Starknet dependency manifest
```

---

## Build & Test

```bash
# Compile Sierra and CASM targets
scarb build

# Run unit and invariant test suite
scarb test
```

---

## License

This project is open-source under the [MIT License](LICENSE).
