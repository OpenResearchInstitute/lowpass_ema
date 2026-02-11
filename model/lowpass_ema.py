"""
Python model of lowpass_ema.vhd — Exponential Moving Average filter.

Matches the RTL pipeline:
  - Clocked process latches alpha_signed, alpha_m, data_signed, mult_data, mult_sum, average
  - Combinational: sum = shift_left(mult_data, MULT_DATA_SHIFT) + shift_left(mult_sum, MULT_SUM_SHIFT)
  - sum_shift = shift_right(sum, SUM_SHIFT_W) resized to MULT_A_W bits
  - average = shift_right(sum, AVG_SHIFT) resized to DATA_W bits

Fixed-point widths (defaults):
  ALPHA_W=18, DATA_W=23, MULT_A_W=25, MULT_B_W=18, PROD_W=43
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))
from model_utils import signed, unsigned


class LowpassEma:
    def __init__(self, alpha_w=18, data_w=23, mult_a_w=25, mult_b_w=18,
                 prod_w=43, fixed_point=False):
        self.ALPHA_W = alpha_w
        self.DATA_W = data_w
        self.MULT_A_W = mult_a_w
        self.MULT_B_W = mult_b_w
        self.PROD_W = prod_w
        self.fixed_point = fixed_point

        # Derived constants matching RTL
        self.SUM_SHIFT_W = self.PROD_W - self.MULT_A_W  # 43-25=18
        self.MULT_DATA_SHIFT = self.PROD_W - self.ALPHA_W - self.DATA_W + 1  # 43-18-23+1=3
        self.MULT_SUM_SHIFT = self.SUM_SHIFT_W - (self.ALPHA_W - 1)  # 18-17=1
        self.AVG_SHIFT = self.PROD_W - self.DATA_W  # 43-23=20

        self.alpha_max = (1 << (self.ALPHA_W - 1)) - 1  # 2^(ALPHA_W-1)-1

        self.reset()

    def reset(self):
        if self.fixed_point:
            self.alpha_signed = 0
            self.alpha_m = 0
            self.data_signed = 0
            self.mult_data = 0
            self.mult_sum = 0
            self._average = 0
            self.average_ena = 0
            # Combinational signals
            self._sum = 0
            self._sum_shift = 0
        else:
            self.ema = 0.0
            self.average_ena = 0

    def step(self, data, data_ena, alpha):
        """One clock cycle. Returns dict(average, average_ena)."""
        if not self.fixed_point:
            return self._step_float(data, data_ena, alpha)
        else:
            return self._step_fixed(data, data_ena, alpha)

    def _step_float(self, data, data_ena, alpha):
        # alpha is a fraction 0..1 (caller converts from fixed-point if needed)
        alpha_frac = alpha if isinstance(alpha, float) else alpha / (1 << self.ALPHA_W)
        self.ema = self.ema + alpha_frac * (data - self.ema)
        self.average_ena = data_ena
        return {
            'average': self.ema,
            'average_ena': self.average_ena
        }

    def _step_fixed(self, data, data_ena, alpha):
        """Match RTL pipeline exactly. All values are Python integers."""
        PW = self.PROD_W
        DW = self.DATA_W
        AW = self.ALPHA_W
        SUMW = self.MULT_A_W  # sum_shift width = PROD_W - SUM_SHIFT_W = MULT_A_W

        # Compute combinational sum BEFORE the register update
        # (uses current registered mult_data and mult_sum values)
        # sum = shift_left(resize(mult_data, PROD_W), MULT_DATA_SHIFT) +
        #       shift_left(resize(mult_sum, PROD_W), MULT_SUM_SHIFT)
        md = signed(self.mult_data, PW) << self.MULT_DATA_SHIFT
        ms = signed(self.mult_sum, PW) << self.MULT_SUM_SHIFT
        self._sum = signed(md + ms, PW)

        # sum_shift = resize(shift_right(sum, SUM_SHIFT_W), MULT_A_W)
        self._sum_shift = signed(self._sum >> self.SUM_SHIFT_W, SUMW)

        # Now update registers (clocked)
        # Save previous sum for output (average uses current sum before update)
        prev_sum = self._sum

        # alpha_signed <= signed(alpha)
        new_alpha_signed = signed(alpha, AW)
        # alpha_m <= alpha_max - alpha_signed
        new_alpha_m = signed(self.alpha_max - self.alpha_signed, AW)
        # data_signed <= signed(data)
        new_data_signed = signed(data, DW)
        # mult_data <= resize(data_signed * alpha_signed, PROD_W)
        new_mult_data = signed(self.data_signed * self.alpha_signed, PW)
        # mult_sum <= resize(sum_shift * alpha_m, PROD_W)
        new_mult_sum = signed(self._sum_shift * self.alpha_m, PW)
        # average <= resize(shift_right(sum, AVG_SHIFT), DATA_W)
        new_average = signed(self._sum >> self.AVG_SHIFT, DW)
        new_average_ena = data_ena

        # Commit register updates
        self.alpha_signed = new_alpha_signed
        self.alpha_m = new_alpha_m
        self.data_signed = new_data_signed
        self.mult_data = new_mult_data
        self.mult_sum = new_mult_sum
        self._average = new_average
        self.average_ena = new_average_ena

        return {
            'average': self._average,
            'average_ena': self.average_ena
        }


if __name__ == "__main__":
    import numpy as np

    # Floating-point demo
    ema = LowpassEma(fixed_point=False)
    alpha = 0.1
    print("Floating-point mode:")
    signal = np.random.randn(20) * 100
    for i, s in enumerate(signal):
        out = ema.step(s, 1, alpha)
        print(f"  [{i:2d}] input={s:8.2f}  avg={out['average']:8.2f}")

    # Fixed-point demo
    print("\nFixed-point mode:")
    ema_fx = LowpassEma(fixed_point=True)
    alpha_fx = 0x8000  # ~0.125 in u0.18
    for i in range(20):
        data = signed(int(signal[i]), 23)
        out = ema_fx.step(data, 1, alpha_fx)
        print(f"  [{i:2d}] input={data:8d}  avg={out['average']:8d}")
