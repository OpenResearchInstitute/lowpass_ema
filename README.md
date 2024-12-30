# Exponential Moving Average (EMA)

Keywords: #filter #lowpass #averaging

This repository contains a VHDL implementation of an **Exponential Moving Average (EMA)**. The EMA is a simple recursive filter commonly used for smoothing input data and identifying trends. It weights recent data points more heavily than older ones, controlled by a smoothing factor.

## Features

- Computes the EMA using the formula:
  \[
  \text{EMA}(n) = \alpha \cdot x(n) + (1 - \alpha) \cdot \text{EMA}(n-1)
  \]
- Fixed-point arithmetic with customizable data width and smoothing factor precision.
- Synchronous operation with clock and reset signals.

## Entity Declaration

### Ports

| Name      | Direction | Width                | Description                                      |
|-----------|-----------|----------------------|--------------------------------------------------|
| `clk`     | Input     | 1 bit                | Clock signal.                                    |
| `init`    | Input     | 1 bit                | Synchronous reset signal.                       |
| `data`    | Input     | `DATA_WIDTH` bits    | Input data to the EMA filter (signed).          |
| `average` | Output    | `DATA_WIDTH` bits    | Filtered EMA output (signed).                   |

### Generics

| Name         | Type    | Default   | Description                                   |
|--------------|---------|-----------|-----------------------------------------------|
| `DATA_WIDTH` | Integer | `16`      | Width of input and output data in bits.       |
| `ALPHA_BITS` | Integer | `8`       | Bit width for the smoothing factor (`alpha`). |

## Architecture

The design computes the EMA in the following steps:
1. **Parameterization:** The smoothing factor (`alpha`) is defined in fixed-point representation. 
   - Example: For 8-bit `ALPHA_BITS`, `alpha = 128` corresponds to \( \alpha = 0.5 \).
2. **Recursive Calculation:** Uses the EMA formula with fixed-point arithmetic.
3. **Output Update:** The result is updated synchronously on each clock cycle.

## Usage

1. **Customization:** Adjust the generics `DATA_WIDTH` and `ALPHA_BITS` in the `ExponentialAverage` entity to fit your design requirements.
2. **Integration:** Instantiate the entity in your top-level design, connect the ports, and configure the input data and clock/reset signals.

### Example Instantiation

```vhdl
ExponentialAverage_inst : entity work.ExponentialAverage
    generic map (
        DATA_WIDTH => 16,
        ALPHA_BITS => 8
    )
    port map (
        clk     => clk,
        init    => init,
        data    => data,
        average => average
    );
```    

3.	**Simulation:** Use a VHDL simulation tool (e.g., ModelSim, GHDL) to verify the functionality. Provide a time-varying input signal to observe the smoothed EMA output.

Applications

	•	Data smoothing (e.g., temperature sensors, financial data).
	•	Noise reduction in signals.
	•	Real-time control systems.


