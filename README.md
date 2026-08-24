# BRT Power Quality Signal Denoising

MATLAB implementation of a Bayesian Residual Transform (BRT) pipeline for
multiscale decomposition and denoising of composite power-quality
disturbance signals — voltage sag, swell, harmonics, flicker, and
transients — under noisy and noise free conditions.

## Overview

Conventional PQ analysis tools (DFT, STFT, Wavelet Transform, S-Transform)
are limited by fixed windows, predefined basis functions, or fixed
time-frequency resolution. This project applies the **Bayesian Residual
Transform** — a basis-free, adaptive multiscale framework — to composite
power-quality signals, combining Nadaraya-Watson kernel regression
decomposition with Median Absolute Deviation (MAD) based thresholding for
noise suppression.

This is the implementation behind the paper *"Enhancing Power Quality
Signals Using Bayesian Residual Transform,"* developed at IIIT
Bhubaneswar.

## Theory & Algorithm

**1. Forward decomposition.** The signal is expressed as a sum of `n`
scale-wise residual components. At each scale, Nadaraya-Watson kernel
regression produces a progressively smoother representation, using a
Gaussian kernel weighted by *amplitude similarity* rather than temporal
distance. The bandwidth grows geometrically across scales
(λⱼ = λ₁ · 1.5^(j−1)). The residual at each scale is the difference
between successive smoothed representations — fine scales capture
noise/transients, coarse scales retain the fundamental and slow envelope
variations (sag, swell).

**2. Noise suppression.** MAD-based soft thresholding is applied to the
detail scales only (the coarsest/final scale is left untouched, since it
carries the fundamental and cannot be safely thresholded).

**3. Reconstruction.** The processed residuals are summed to recover the
denoised signal.

Evaluation uses four metrics: **correlation coefficient**, **RMSE**,
**SNRI** (SNR improvement), and **THD** (checked against the IEEE
519-2022 5% voltage limit).

Original BRT framework:
> A. Wong and X. Y. Wang, "A Bayesian Residual Transform for Signal
> Processing," *IEEE Access*, vol. 3, pp. 709–717, 2015.
> DOI: [10.1109/ACCESS.2015.2437873](https://doi.org/10.1109/ACCESS.2015.2437873)

MAD-based soft thresholding follows:
> D. L. Donoho, "De-noising by soft-thresholding," *IEEE Trans. Inf.
> Theory*, vol. 41, no. 3, pp. 613–627, 1995.

The application of BRT to **composite** power-quality disturbances —
multi-disturbance signal modeling per IEEE Std. 1159-2019 / IEC
61000-4-x, the six-scale parameterization, scale-wise SNRI/THD analysis,
and threshold-factor sweep — is the contribution of this project.

## Repository Structure

| File | Purpose |
|---|---|
| `BRT_PowerQuality_main.m` | Entry point — configures signal, runs multi-trial BRT analysis |
| `BRT_signal_generation.m` | Generates the composite PQ disturbance signal (sag, swell, harmonics, flicker, transient, noise) per IEEE 1159-2019 / IEC 61000-4-x |
| `BRT_forward.m` | Forward BRT — cascaded Nadaraya-Watson kernel regression decomposition |
| `BRT_noise_suppress.m` | MAD-based soft thresholding of detail-scale residuals |
| `BRT_inverse.m` | Signal reconstruction (sum of processed residuals) |
| `BRT_calculate_and_plot.m` | Metrics computation (correlation, RMSE, SNRI, THD) and visualization |

## Requirements

MATLAB — no additional toolboxes required.

## Usage

```matlab
BRT_PowerQuality_main          % interactive prompts, Enter = use defaults
BRT_PowerQuality_main(false)   % run fully with defaults, no prompts
```

## Simulation Configuration

| Parameter | Value | Standard |
|---|---|---|
| Fundamental frequency | 50 Hz | IEEE Std. 1159-2019 |
| Sampling frequency | 10,000 Hz | IEC 61000-4-7 |
| Observation window | 0.5 s (25 cycles, 5000 samples) | — |
| Sag depth | 0.6 pu | IEEE 1159-2019 §4.4.1 |
| Swell magnitude | 0.3 pu | IEEE 1159-2019 §4.4.2 |
| Harmonics | 3rd & 5th, 0.05 pu each | IEC 61000-4-7 |
| Flicker | 0.10 pu modulation @ 10 Hz | IEC 61000-4-15 |
| Transient | 2.0 pu, τ = 10 ms | IEEE 1159-2019 §4.3 |
| Noise | AWGN, ~20 dB input SNR | — |
| Decomposition scales | 6 (kernel sizes 1, 2, 4, 7, 12, 20) | — |
| Threshold factor (k_thresh) | 2.5 (optimal band: 2.0–3.5) | — |

## Results

## Results

Over 10 independent noise trials:

| Metric | Noise-free | With Noise (SNR ≈ 20 dB) |
|---|---|---|
| Correlation coefficient | 0.9484 | 0.9480 ± 0.0003 |
| RMSE (pu) | 0.0394 | 0.0416 ± 0.0008 |
| SNRI (dB) | N/A | ≈ 5.0 |
| Output THD (%) | 4.96 | 5.32 |

**Scale-wise residual decomposition.** The input signal is decomposed into
six residual scales (kernel sizes 1–20). Fine scales (r₁–r₄) isolate
high-frequency noise, which MAD thresholding suppresses toward zero,
while the coarsest scale (r₆) retains the fundamental and the sag/swell
envelope.

![Scale-wise BRT decomposition](figures/BRT_Fig1_Signal_Analysis.png)

**Forward cascade.** As kernel size increases, each stage of the cascade
produces a progressively smoother approximation of the signal, while
still preserving the sag event around 250 ms throughout every stage.

![Forward BRT cascade](figures/BRT_Fig3_Cascade.png)

**Scale-wise SNRI and THD.** Thresholding the first three detail scales
gives the largest noise-suppression gain (SNRI peaks at ≈10.8 dB at
j = 3); thresholding a fourth scale adds little, and a fifth scale
degrades SNRI back down to ≈5.2 dB by removing signal-bearing content.
THD falls monotonically with each added scale, from a 9.46% baseline to
5.3% once all detail scales are thresholded, crossing the IEEE 519-2022
8% mark at j = 3.

![Scale-wise SNRI and THD vs. thresholded scales](figures/BRT_Fig5_Scalewise_SNRI_THD.png)

## Authors

**Dibya Ranjan Pany** — Electrical and Electronics Engineering, IIIT
Bhubaneswar
*(Repository maintainer — MATLAB implementation, algorithm development, and validation)*

## Acknowledgements

- **Dibya Ranjan Pany** — EEE, IIIT Bhubaneswar
- **Ayushman Sethy** — EEE, IIIT Bhubaneswar
- **Rishandh Das K S** — EEE, IIIT Bhubaneswar
- **Dr. Debani Prasad Mishra** — Dept. of Electrical Engineering, IIIT Bhubaneswar
- **Rudranarayan Senapati** — School of Electrical Engineering, KIIT Deemed to be University
- **Sarita Samal** — School of Electrical Engineering, KIIT Deemed to be University

Core algorithm concept credited to Wong & Wang (2015); MAD-based
thresholding methodology credited to Donoho (1995).
