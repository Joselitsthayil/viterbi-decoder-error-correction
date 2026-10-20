
# Viterbi Decoder for Random Error Correction

## 1. Project Overview

This project focuses on the design and simulation of a Viterbi decoding system for error correction in digital communication. The design uses a convolutional coding scheme with a code rate of 1/2, constraint length of 3, and generator polynomials G1 = 111 and G2 = 101.

The convolutional encoder generates two output bits for every input bit. The Viterbi decoder estimates the most likely transmitted sequence by evaluating possible state transitions and selecting the path with the lowest accumulated distance.

The project focuses on convolutional encoding, trellis-based decoding, branch metric calculation, path metric updates, and hardware-oriented implementation using Verilog HDL and Xilinx Vivado.

## 2. Objectives

- Implement a rate-1/2 convolutional encoder with constraint length 3.
- Generate encoded data using generator polynomials G1 = 111 and G2 = 101.
- Develop a Viterbi decoder to recover the transmitted information sequence.
- Implement branch metric and path metric calculations.
- Apply the Add-Compare-Select (ACS) operation to select survivor paths.
- Verify the encoder and decoder using Verilog testbenches.
- Evaluate error-correction performance through simulation with controlled bit errors.

## 3. System Specifications

| Parameter | Specification |
|---|---|
| Coding technique | Convolutional coding |
| Code rate | 1/2 |
| Constraint length | 3 |
| Generator polynomial G1 | 111 (binary) |
| Generator polynomial G2 | 101 (binary) |
| Encoder memory elements | 2 |
| Number of trellis states | 4 |
| RTL language | Verilog HDL |
| Simulation tool | Xilinx Vivado |

The specifications describe the intended design. The state encoding, generator tap convention, output ordering, and reset behaviour should match the actual Verilog implementation.

## 4. System Architecture

The proposed system can be organized into the following stages:

1. **Input Data Generation:** Generate the binary information sequence to be transmitted.
2. **Convolutional Encoding:** Convert each input bit into two encoded bits using the specified generator polynomials.
3. **Communication Channel:** Introduce controlled bit errors to test the decoder's error-correction capability.
4. **Branch Metric Calculation:** Compare the received bits with the expected output bits for each candidate transition.
5. **Path Metric Update:** Accumulate the branch metrics and determine the lowest-cost paths.
6. **Survivor Path Selection:** Use the Add-Compare-Select operation to retain the most likely path to each state.
7. **Traceback and Decoding:** Use the stored survivor decisions to reconstruct the most likely input sequence.
8. **Output Verification:** Compare the decoded sequence against the original input data.

## 5. Mathematical Formulation

The following equations use plain-text notation for readability in GitHub.

### 5.1 Convolutional Encoding

The encoder stores the current input bit and the two previous input bits.

Let:

- u[n] = current input bit
- u[n-1] = previous input bit
- u[n-2] = input bit from two time steps earlier
- c1[n] and c2[n] = the two encoded output bits

For the generator polynomials G1 = 111 and G2 = 101, assuming the rightmost polynomial bit corresponds to the current input, the output equations are:

```text
c1[n] = u[n] XOR u[n-1] XOR u[n-2]

c2[n] = u[n] XOR u[n-2]
```

Here, XOR denotes the exclusive-OR operation.

The encoded output for each input bit is:

```text
Encoded output = (c1[n], c2[n])
```

Since the code rate is 1/2, two encoded bits are produced for every input bit, excluding any additional termination or framing overhead.

### 5.2 Number of Trellis States

The number of trellis states depends on the number of memory elements in the encoder.

```text
Memory elements = Constraint length - 1

m = K - 1

Number of states = 2^m
```

For a constraint length of K = 3:

```text
m = 3 - 1 = 2

Number of states = 2^2 = 4
```

Therefore, the decoder operates using four possible trellis states, corresponding to the four combinations of the two stored bits.

### 5.3 Branch Metric Calculation

For hard-decision decoding, the Hamming distance measures the number of bit positions that differ between the received encoded pair and the expected encoded pair.

Let:

- r1, r2 = received bits
- c1, c2 = expected encoded bits

The branch metric is:

```text
BM = (r1 XOR c1) + (r2 XOR c2)
```

Each XOR operation produces either 0 or 1. Therefore, the branch metric can take values from 0 to 2.

Example:

```text
Received bits:  10
Expected bits:  11

Bit differences: 1

Branch metric = 1
```

A branch metric of 0 indicates a perfect match, while a higher value indicates more bit differences.

### 5.4 Path Metric Calculation

The path metric represents the accumulated cost of a path through the trellis.

For a destination state s at time step n, the decoder calculates:

```text
Candidate path metric =
Previous path metric + Branch metric
```

If multiple paths enter the same destination state, the decoder selects the path with the lowest candidate metric.

The mathematical relationship is:

```text
PM[n][s] =
    minimum over all predecessor states s' of:
    PM[n-1][s'] + BM[n][s' -> s]
```

where:

- PM[n][s] = path metric for state s at time n
- PM[n-1][s'] = path metric of the predecessor state
- BM[n][s' -> s] = branch metric for the transition from s' to s

This process is repeated for each received encoded pair.

### 5.5 Add-Compare-Select (ACS) Operation

The ACS unit is a key component of the Viterbi decoder.

For every candidate transition, it performs three operations:

1. **Add:** Add the branch metric to the predecessor path metric.
2. **Compare:** Compare the candidate metrics entering the same destination state.
3. **Select:** Retain the path with the lowest metric and store its survivor decision.

The survivor decisions are subsequently used during traceback to estimate the transmitted data sequence.

### 5.6 Bit Error Rate (BER)

The bit error count is the number of positions where the original input differs from the decoded output.

```text
Error count =
Number of positions where original bit != decoded bit
```

The bit error rate is:

```text
BER = Number of incorrectly decoded bits
      ------------------------------------
             Total compared bits
```

For example, if 4 bits are incorrectly decoded out of 1,000 compared bits:

```text
BER = 4 / 1000 = 0.004
```

Expressed as a percentage:

```text
BER percentage = 0.004 x 100 = 0.4%
```

For successful error-free recovery, the expected BER is 0 over the compared input sequence. The comparison must account for decoder latency, traceback delay, and encoder termination conventions.

## 6. Tools and Technologies

| Category | Tool / Technology |
|---|---|
| Hardware description | Verilog HDL |
| Functional simulation | Xilinx Vivado |
| Coding technique | Convolutional encoding |
| Decoding algorithm | Viterbi algorithm |
| Verification | Testbench-based simulation |
| Application domain | Digital communication and error correction |

## 7. Implementation and Verification

### 7.1 Convolutional Encoder

Implement the encoder using a shift register and XOR logic corresponding to G1 = 111 and G2 = 101.

Verify that the encoded output matches the expected output for representative input sequences.

### 7.2 Viterbi Decoder

The decoder should process each received pair using the following operations:

- Calculate branch metrics for valid state transitions.
- Update the path metrics for all destination states.
- Select survivor paths using the ACS operation.
- Store survivor decisions for traceback.
- Recover the estimated transmitted sequence.

### 7.3 Testbench Verification

The testbench should compare the decoded data with the original input sequence under different transmission conditions.

Recommended test scenarios include:

**Error-free transmission:** Encode the input sequence and decode it without introducing errors. Verify that the recovered sequence matches the original after accounting for decoding latency.

**Single-bit error:** Flip one bit in a received encoded pair and determine whether the decoder recovers the original information sequence.

**Multiple bit errors:** Introduce controlled errors at different positions and measure the resulting decoding performance.

**State and reset testing:** Check state transitions, initial path metrics, reset behaviour, and survivor decisions.

**Automated comparison:** Implement a self-checking testbench that reports pass or fail for each test case.

Actual error-correction capability depends on the received sequence, error pattern, termination method, and decoder implementation. Simulation results should be recorded before making quantitative performance claims.

## 8. Expected Functional Modules

The design can be organized using the following modules, depending on the actual implementation:

- **Convolutional Encoder:** Generates two coded output bits per input bit.
- **Trellis State Logic:** Represents the four possible encoder states and transitions.
- **Branch Metric Unit:** Calculates the Hamming distance for each candidate transition.
- **Path Metric Unit:** Updates and compares accumulated path costs.
- **ACS Unit:** Selects the minimum-cost survivor path.
- **Traceback Unit:** Reconstructs the likely transmitted sequence.
- **Output Control:** Manages reset, valid output data, and decoding latency.

The module names and boundaries should be updated to match the actual RTL source files.

## 9. Verification Results

Record the results after running the Verilog testbench in Vivado.

| Test case | Expected behaviour | Actual result |
|---|---|---|
| Error-free transmission | Recover the original sequence | To be recorded |
| Single-bit error | Evaluate error correction | To be recorded |
| Multiple bit errors | Evaluate decoding robustness | To be recorded |
| Reset operation | Initialize decoder correctly | To be recorded |
| State transition testing | Follow valid trellis transitions | To be recorded |

No area, power, timing, or measured BER values are claimed because verified results for this implementation have not yet been documented.

## 10. Limitations and Future Scope

- Evaluate decoding performance under different error rates and channel conditions.
- Optimize path metric storage and survivor decision memory.
- Investigate traceback depth and its effect on latency and decoding reliability.
- Implement fixed-width path metrics with appropriate overflow management.
- Extend the design to support configurable constraint lengths and generator polynomials.
- Compare hard-decision and soft-decision decoding.
- Evaluate area, power, and timing after synthesis.
- Add automated regression tests for functional correctness and error recovery.

## 11. Repository Structure

```text
viterbi-decoder-error-correction/
├── README.md
├── rtl/
│   ├── convolutional_encoder.v
│   ├── branch_metric.v
│   ├── path_metric.v
│   ├── viterbi_decoder.v
│   └── traceback.v
├── testbench/
│   ├── tb_convolutional_encoder.v
│   ├── tb_viterbi_decoder.v
│   └── test_vectors/
├── simulation/
│   └── waveforms/
├── results/
│   ├── error_correction/
│   └── verification/
└── docs/
    └── architecture.md
```



This repository documents the intended design and verification approach for a Verilog-based Viterbi decoder. Final claims about error correction, hardware performance, and functional correctness should be supported by simulation or synthesis evidence.
