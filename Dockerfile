# Build from this repo's root (Grand Challenge's GitHub-linked build looks
# for ./Dockerfile at repo root with no configurable path -- this repo
# exists specifically so Task 3 can have its own GC Algorithm/build,
# separate from Task 1's and Task 2's repos):
#   docker build --platform=linux/amd64 -f Dockerfile -t doserad2026_task3_proton_ct .
FROM --platform=linux/amd64 pytorch/pytorch:2.9.1-cuda12.6-cudnn9-runtime AS task3_proton_ct

ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/opt/app

RUN groupadd -r user && useradd -m --no-log-init -r -g user user
USER user

WORKDIR /opt/app

COPY --chown=user:user requirements.txt /opt/app/
RUN python -m pip install \
    --user \
    --no-cache-dir \
    --no-color \
    --requirement /opt/app/requirements.txt

COPY --chown=user:user app.py process.py /opt/app/
COPY --chown=user:user src/ /opt/app/src/
COPY --chown=user:user configs/task3_proton_ct.yaml /opt/app/configs/task3_proton_ct.yaml

LABEL org.grand-challenge.api-method="invoke"

ENTRYPOINT ["python", "app.py"]
