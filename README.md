# DoseRAD2026 — Proton Dose Prediction on CT

Submission code for the proton/CT task of the
[DoseRAD2026 Grand Challenge](https://doserad2026.grand-challenge.org/):
predicting a 3D radiation dose distribution (Geant4 Monte Carlo ground
truth) for a single pencil-beam-scanning (PBS) beamlet, directly from a
patient CT volume and that beamlet's source, target, and energy.

The full write-up — architecture, training, the water-equivalent-path-length
(WEPL) correction, and an honestly-reported train/inference mismatch found
in this submission after it was already scored — is the companion LNCS
report, [*A Physics-Conditioned 3D U-Net for Proton Dose Prediction on
CT*](https://github.com/JyothiSreeMasina/Doserad2026/blob/main/paper/proton_dose_ct_lncs.pdf),
in the main project repository. Read Section 3 of that report before relying
on this submission's numbers — it documents a real defect (detailed below)
that this code still contains, by design, because that is what was actually
scored.

## Approach

The same 3D U-Net used across this team's four DoseRAD2026 submissions
(5-level encoder/decoder, 16–32–64–128–256 channels, two residual units per
block, ~4.8M parameters, built on [MONAI](https://monai.io/)'s `UNet`) takes
a two-channel input — a normalized CT volume and a beamlet-conditioning
mask — and predicts a single-channel dose volume. Proton pencil beams have
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
WEPL correction was wired into the training loop — it was trained entirely
under the water-only range assumption. `process.py`'s inference path,
however, **does** pass the CT-derived correction at prediction time. That
mismatch was found after this entry had already been submitted and scored;
it is described in full, with the file-timestamp evidence that established
it, in Section 3.3 of the paper linked above. It has not been fixed and
resubmitted. This repository's code intentionally reflects that mismatch
rather than a quietly "improved" version, because the goal here is to
reproduce what was actually scored, not a hypothetical corrected variant.
`src/data/beam_encoder.py` does carry one related fix on top of the scored
checkpoint's era: a fallback bug in the WEPL correction (a bad clamp that
was off by up to 121mm for beamlets exiting near the patient surface) found
and fixed during the same post-submission investigation — see Section 3.2
of the paper.

## Layout

```
src/                Data pipeline, beam encoder, model, losses, training loop, evaluation metrics
configs/             Training config (beam type, modality, hyperparameters)
app.py, process.py   Grand Challenge /health + /invoke submission server
Dockerfile           Container build (root-level, for Grand Challenge's repo-linked build)
```

## Reproducing

```bash
pip install -r requirements.txt
```

The `src/` package here is the same training/evaluation library used across
this team's four DoseRAD2026 submissions; the training entry point
(`scripts/train.py`) lives in the
[main project repository](https://github.com/JyothiSreeMasina/Doserad2026),
run against `configs/task3_proton_ct.yaml` from this repo.

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
