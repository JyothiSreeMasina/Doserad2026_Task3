# DoseRAD2026: Proton Dose Prediction on CT

Submission code for the proton/CT task of the
[DoseRAD2026 Grand Challenge](https://doserad2026.grand-challenge.org/):
predicting a 3D radiation dose distribution (Geant4 Monte Carlo ground
truth) for a single pencil-beam-scanning (PBS) beamlet, directly from a
patient CT volume and that beamlet's source, target, and energy.

## Approach

The same 3D U-Net used across this team's four DoseRAD2026 submissions
(5-level encoder/decoder, 16-32-64-128-256 channels, two residual units per
block, ~4.8M parameters, built on [MONAI](https://monai.io/)'s `UNet`) takes
a two-channel input, a normalized CT volume and a beamlet-conditioning
mask, and predicts a single-channel dose volume. Proton pencil beams have
no MLC-aperture analogue, so the beamlet mask comes from an analytic,
first-principles encoder (`ProtonBeamEncoder` in `src/data/beam_encoder.py`)
rather than ray tracing: range from the Bragg-Kleeman relation, range
straggling from Bortfeld's mono-energetic approximation, lateral spread from
the Highland multiple-Coulomb-scattering formula, and an optional
water-equivalent-path-length correction that samples CT-derived stopping
power along the beamlet axis to place the Bragg peak using real tissue
density instead of assuming the whole path is water.

## A known, disclosed defect in this submission

The checkpoint packaged in this container finished training **before** the
WEPL correction was wired into the training loop. It was trained entirely
under the water-only range assumption. `process.py`'s inference path,
however, **does** pass the CT-derived correction at prediction time. That
mismatch was found after this entry had already been submitted and scored.
It has not been fixed and resubmitted. This repository's code intentionally
reflects that mismatch rather than a quietly "improved" version, because
the goal here is to reproduce what was actually scored, not a hypothetical
corrected variant. `src/data/beam_encoder.py` does carry one related fix on
top of the scored checkpoint's era: a fallback bug in the WEPL correction
(a bad clamp that was off by up to 121mm for beamlets exiting near the
patient surface) found and fixed during the same post-submission
investigation.

## Layout

```
src/                Data pipeline, beam encoder, model, losses, training loop, evaluation metrics
scripts/             train.py, evaluate_cloud.py: training and evaluation entry points
configs/             Training config (beam type, modality, hyperparameters)
app.py, process.py   Grand Challenge /health + /invoke submission server
Dockerfile           Container build (root-level, for Grand Challenge's repo-linked build)
```

## Reproducing

```bash
pip install -r requirements.txt
```

**Train:**
```bash
python scripts/train.py --config configs/task3_proton_ct.yaml
```

**Evaluate against local held-out patients:**
```bash
python scripts/evaluate_cloud.py --config configs/task3_proton_ct.yaml --checkpoint checkpoints/task3_proton_ct/best.pt
```

Training data (75 patients, CT + proton beam JSON + Geant4 beamlet-level
dose) is released by the challenge organizers on
[Zenodo](https://doi.org/10.5281/zenodo.19347848) and is not included here.

**Build and run the submission container:**
```bash
docker build --platform=linux/amd64 -f Dockerfile -t doserad2026_task3_proton_ct .
```
The container implements the platform's required `/health` + `/invoke` HTTP
API and the documented 10-slot batched image/metadata I/O contract.

## Weights

Trained checkpoints are not tracked in this repository. The one actually
submitted and scored is uploaded to the Grand Challenge platform separately
from the container image, per the platform's own `model.tar.gz` mechanism.

## License

CC BY-NC 4.0, matching the DoseRAD2026 dataset license.
