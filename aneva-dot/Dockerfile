FROM rocker/r-ver:4.1.1

LABEL org.opencontainers.image.title="ANEVA-DOT" \
    org.opencontainers.image.url="https://github.com/PejLab/ANEVA-DOT" \
    org.opencontainers.image.version="0.1.1"

RUN R --no-echo --no-save --no-restore -e "install.packages('remotes')" && \
    R --no-echo --no-save --no-restore -e "remotes::install_github('LappalainenLab/dottools', dependencies = TRUE)"

RUN ln -vs $(Rscript -e "cat(dottools::dot_script())") /usr/local/bin

CMD [ "/bin/bash" ]
