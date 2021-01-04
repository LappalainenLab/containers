FROM ubuntu:bionic

LABEL org.opencontainers.image.title="phaser" \
    org.opencontainers.image.url="https://github.com/secastel/phaser" \
    org.opencontainers.image.version="1.1.1"

RUN apt-get update && apt-get install -y \
    git \
    tabix \
    samtools \
    bedtools \
    bcftools \
    python-dev \
    python-pip && \
    pip install \
    cython \
    numpy==1.16.4 \
    scipy==1.2.2 \
    pandas==0.24.2 \
    pysam \
    intervaltree && \
    git clone https://github.com/secastel/phaser && \
    cd /phaser/phaser && \
    python setup.py build_ext --inplace && \
    sed -i '1c#!\/usr\/bin\/env python' phaser.py && \
    chmod +x phaser.py && \
    ln -vs $(realpath phaser.py) /usr/local/bin && \
    cd /phaser/phaser_gene_ae && \
    echo '#!/usr/bin/env python' | cat - phaser_gene_ae.py > /usr/local/bin/phaser_gene_ae.py && \
    chmod +x /usr/local/bin/phaser_gene_ae.py

CMD [ "/bin/bash" ]
